/*
 * Copyright (c) 2023, Tim Flynn <trflynn89@serenityos.org>
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <Ladybird/Utilities.h>
#include <LibCore/ArgsParser.h>
#include <LibCore/EventLoop.h>
#include <LibGfx/Font/FontDatabase.h>
#include <LibMain/Main.h>

#import <Application/ApplicationDelegate.h>
#import <Application/EventLoopImplementation.h>
#import <UI/Tab.h>
#import <UI/TabController.h>
#import <Utilities/URL.h>

#if !__has_feature(objc_arc)
#    error "This project requires ARC"
#endif

ErrorOr<int> serenity_main(Main::Arguments arguments)
{
    [NSApplication sharedApplication];

    Core::EventLoopManager::install(*new Ladybird::CFEventLoopManager);
    Core::EventLoop event_loop;

    platform_init();

    // NOTE: We only instantiate this to ensure that Gfx::FontDatabase has its default queries initialized.
    Gfx::FontDatabase::set_default_font_query("Katica 10 400 0");
    Gfx::FontDatabase::set_fixed_width_font_query("Csilla 10 400 0");

    StringView url;

    Core::ArgsParser args_parser;
    args_parser.set_general_help("The Ladybird web browser");
    args_parser.add_positional_argument(url, "URL to open", "url", Core::ArgsParser::Required::No);
    args_parser.parse(arguments);

    Optional<URL> initial_url;
    if (auto parsed_url = Ladybird::sanitize_url(url); parsed_url.is_valid()) {
        initial_url = move(parsed_url);
    }

    [NSApp setDelegate:[[ApplicationDelegate alloc] init:move(initial_url)]];
    [NSApp activateIgnoringOtherApps:YES];

    return event_loop.exec();
}
