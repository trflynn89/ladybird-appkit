/*
 * Copyright (c) 2023, Tim Flynn <trflynn89@serenityos.org>
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <Ladybird/Utilities.h>
#include <LibCore/EventLoop.h>
#include <LibGfx/Font/FontDatabase.h>

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

    platform_init();

    // NOTE: We only instantiate this to ensure that Gfx::FontDatabase has its default queries initialized.
    Gfx::FontDatabase::set_default_font_query("Katica 10 400 0");
    Gfx::FontDatabase::set_fixed_width_font_query("Csilla 10 400 0");

    [NSApp setDelegate:[[ApplicationDelegate alloc] init]];
    [NSApp activateIgnoringOtherApps:YES];

    return event_loop.exec();
}
