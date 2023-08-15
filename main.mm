/*
 * Copyright (c) 2023, Tim Flynn <trflynn89@serenityos.org>
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <LibCore/EventLoop.h>

#import <Application/ApplicationDelegate.h>
#import <Application/EventLoopImplementation.h>
#import <UI/Tab.h>
#import <UI/TabController.h>

#if !__has_feature(objc_arc)
#    error "This project requires ARC"
#endif

int main()
{
    [NSApplication sharedApplication];

    Core::EventLoopManager::install(*new CFEventLoopManager);
    Core::EventLoop event_loop;

    [NSApp setDelegate:[[ApplicationDelegate alloc] init]];
    [NSApp activateIgnoringOtherApps:YES];

    return event_loop.exec();
}
