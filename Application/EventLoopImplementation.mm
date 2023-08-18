/*
 * Copyright (c) 2023, Tim Flynn <trflynn89@serenityos.org>
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <AK/Assertions.h>
#include <AK/IDAllocator.h>
#include <LibCore/Event.h>
#include <LibCore/Notifier.h>
#include <LibCore/ThreadEventQueue.h>

#import <Application/EventLoopImplementation.h>
#import <System/Cocoa.h>
#import <System/CoreFoundation.h>

namespace Ladybird {

struct ThreadData;
static thread_local ThreadData* s_thread_data;

struct ThreadData {
    static ThreadData& the()
    {
        if (!s_thread_data) {
            // FIXME: Don't leak this.
            s_thread_data = new ThreadData;
        }

        return *s_thread_data;
    }

    IDAllocator timer_id_allocator;
    HashMap<int, CFRunLoopTimerRef> timers;
    HashMap<Core::Notifier*, CFRunLoopSourceRef> notifiers;
};

NonnullOwnPtr<Core::EventLoopImplementation> CFEventLoopManager::make_implementation()
{
    return CFEventLoopImplementation::create();
}

int CFEventLoopManager::register_timer(Core::EventReceiver& receiver, int interval_milliseconds, bool should_reload, Core::TimerShouldFireWhenNotVisible should_fire_when_not_visible)
{
    auto& thread_data = ThreadData::the();

    auto timer_id = thread_data.timer_id_allocator.allocate();
    auto weak_receiver = receiver.make_weak_ptr();

    auto interval_seconds = static_cast<double>(interval_milliseconds) / 1000.0;
    auto first_fire_time = CFAbsoluteTimeGetCurrent() + interval_seconds;

    auto timer = CFRunLoopTimerCreateWithHandler(
        kCFAllocatorDefault, first_fire_time, should_reload ? interval_seconds : 0, 0, 0,
        ^(CFRunLoopTimerRef) {
            auto receiver = weak_receiver.strong_ref();
            if (!receiver) {
                return;
            }

            if (should_fire_when_not_visible == Core::TimerShouldFireWhenNotVisible::No) {
                if (!receiver->is_visible_for_timer_purposes()) {
                    return;
                }
            }

            Core::TimerEvent event(timer_id);
            receiver->dispatch_event(event);
        });

    CFRunLoopAddTimer(CFRunLoopGetCurrent(), timer, kCFRunLoopDefaultMode);
    thread_data.timers.set(timer_id, timer);

    return timer_id;
}

bool CFEventLoopManager::unregister_timer(int timer_id)
{
    auto& thread_data = ThreadData::the();
    thread_data.timer_id_allocator.deallocate(timer_id);

    if (auto timer = thread_data.timers.take(timer_id); timer.has_value()) {
        CFRunLoopTimerInvalidate(*timer);
        return true;
    }

    return false;
}

static void socket_notifier(CFSocketRef, CFSocketCallBackType, CFDataRef, void const*, void* info)
{
    auto& notifier = *reinterpret_cast<Core::Notifier*>(info);

    Core::NotifierActivationEvent event(notifier.fd());
    notifier.dispatch_event(event);
}

void CFEventLoopManager::register_notifier(Core::Notifier& notifier)
{
    auto notification_type = kCFSocketNoCallBack;

    switch (notifier.type()) {
    case Core::Notifier::Type::Read:
        notification_type = kCFSocketReadCallBack;
        break;
    case Core::Notifier::Type::Write:
        notification_type = kCFSocketWriteCallBack;
        break;
    default:
        TODO();
        break;
    }

    CFSocketContext context { .info = &notifier };
    auto socket = CFSocketCreateWithNative(kCFAllocatorDefault, notifier.fd(), notification_type, &socket_notifier, &context);

    auto source = CFSocketCreateRunLoopSource(kCFAllocatorDefault, socket, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopDefaultMode);
    CFRelease(source);

    ThreadData::the().notifiers.set(&notifier, source);
}

void CFEventLoopManager::unregister_notifier(Core::Notifier& notifier)
{
    if (auto source = ThreadData::the().notifiers.take(&notifier); source.has_value()) {
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), *source, kCFRunLoopDefaultMode);
        CFRelease(*source);
    }
}

void CFEventLoopManager::did_post_event()
{
    auto* event = [NSEvent otherEventWithType:NSEventTypeApplicationDefined
                                     location:NSMakePoint(0, 0)
                                modifierFlags:0
                                    timestamp:0
                                 windowNumber:0
                                      context:nil
                                      subtype:0
                                        data1:0
                                        data2:0];

    [NSApp postEvent:event atStart:NO];
}

NonnullOwnPtr<CFEventLoopImplementation> CFEventLoopImplementation::create()
{
    return adopt_own(*new CFEventLoopImplementation);
}

int CFEventLoopImplementation::exec()
{
    [NSApp run];
    return m_exit_code;
}

size_t CFEventLoopImplementation::pump(PumpMode mode)
{
    auto* wait_until = mode == PumpMode::WaitForEvents ? [NSDate distantFuture] : [NSDate distantPast];

    auto* event = [NSApp nextEventMatchingMask:NSEventMaskAny
                                     untilDate:wait_until
                                        inMode:NSDefaultRunLoopMode
                                       dequeue:YES];

    if (event) {
        if (event.type == NSEventTypeApplicationDefined) {
            m_thread_event_queue.process();
        } else {
            [NSApp sendEvent:event];
        }
    }

    return 0;
}

void CFEventLoopImplementation::quit(int exit_code)
{
    m_exit_code = exit_code;
    [NSApp stop:nil];
}

void CFEventLoopImplementation::wake()
{
    CFRunLoopWakeUp(CFRunLoopGetCurrent());
}

void CFEventLoopImplementation::post_event(Core::EventReceiver& receiver, NonnullOwnPtr<Core::Event>&& event)
{
    m_thread_event_queue.post_event(receiver, move(event));

    if (&m_thread_event_queue != &Core::ThreadEventQueue::current())
        wake();
}

}
