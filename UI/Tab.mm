/*
 * Copyright (c) 2023, Tim Flynn <trflynn89@serenityos.org>
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <AK/DeprecatedString.h>
#include <AK/StringView.h>
#include <AK/URL.h>
#include <AK/Vector.h>
#include <BrowserSettings/Defaults.h>
#include <Ladybird/Utilities.h>

#import <UI/LadybirdWebView.h>
#import <UI/Tab.h>
#import <UI/TabController.h>
#import <Utilities/Conversions.h>

#if !__has_feature(objc_arc)
#    error "This project requires ARC"
#endif

static constexpr CGFloat const WINDOW_WIDTH = 1000;
static constexpr CGFloat const WINDOW_HEIGHT = 800;

static NSString* rebase_url_on_serenity_resource_root(StringView default_url)
{
    URL url { default_url };
    Vector<DeprecatedString> paths;

    for (auto segment : s_serenity_resource_root.split('/'))
        paths.append(move(segment));

    for (size_t i = 0; i < url.path_segment_count(); ++i)
        paths.append(url.path_segment_at_index(i));

    url.set_paths(move(paths));

    return string_to_ns_string(url.serialize());
}

@interface Tab ()

@end

@implementation Tab

- (instancetype)init
{
    auto screen_rect = [[NSScreen mainScreen] frame];
    auto position_x = (NSWidth(screen_rect) - WINDOW_WIDTH) / 2;
    auto position_y = (NSHeight(screen_rect) - WINDOW_HEIGHT) / 2;

    auto window_rect = NSMakeRect(position_x, position_y, WINDOW_WIDTH, WINDOW_HEIGHT);
    auto style_mask = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable;

    self = [super initWithContentRect:window_rect
                            styleMask:style_mask
                              backing:NSBackingStoreBuffered
                                defer:NO];

    if (self) {
        [self setTitle:@"New Tab - Ladybird"];
        [self setTitleVisibility:NSWindowTitleHidden];
        [self setIsVisible:YES];

        self.web_view = [[LadybirdWebView alloc] init];
        [self setContentView:self.web_view];

        auto* new_tab_url = rebase_url_on_serenity_resource_root(Browser::default_new_tab_url);
        [self.web_view load:new_tab_url];
    }

    return self;
}

@end
