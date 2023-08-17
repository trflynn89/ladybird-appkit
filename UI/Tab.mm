/*
 * Copyright (c) 2023, Tim Flynn <trflynn89@serenityos.org>
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#import <UI/LadybirdWebView.h>
#import <UI/Tab.h>
#import <UI/TabController.h>

#if !__has_feature(objc_arc)
#    error "This project requires ARC"
#endif

static constexpr CGFloat const WINDOW_WIDTH = 1000;
static constexpr CGFloat const WINDOW_HEIGHT = 800;

@implementation Tab

- (instancetype)init:(URL)url
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

        auto* scroll_view = [[NSScrollView alloc] initWithFrame:[self frame]];
        [scroll_view setHasVerticalScroller:YES];
        [scroll_view setHasHorizontalScroller:YES];
        [scroll_view setLineScroll:24];

        self.web_view = [[LadybirdWebView alloc] init];
        [self.web_view setPostsBoundsChangedNotifications:YES];

        [scroll_view setContentView:self.web_view];
        [scroll_view setDocumentView:[[NSView alloc] init]];

        [[NSNotificationCenter defaultCenter]
            addObserver:self
               selector:@selector(onContentScroll:)
                   name:NSViewBoundsDidChangeNotification
                 object:[scroll_view contentView]];

        [self setContentView:scroll_view];

        [self.web_view load:url];
    }

    return self;
}

#pragma mark - Private methods

- (void)onContentScroll:(NSNotification*)notification
{
    [[self web_view] handleScroll];
}

@end
