/*
 * Copyright (c) 2023, Tim Flynn <trflynn89@serenityos.org>
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <AK/DeprecatedString.h>
#include <AK/String.h>
#include <AK/StringView.h>
#include <AK/URL.h>
#include <UI/LadybirdWebViewBridge.h>

#import <UI/LadybirdWebView.h>
#import <UI/Tab.h>
#import <UI/TabController.h>
#import <Utilities/Conversions.h>

@interface LadybirdWebView ()
{
    OwnPtr<LadybirdWebViewBridge> m_web_view_bridge;
}

@end

@implementation LadybirdWebView

- (instancetype)init
{
    if (self = [super init]) {
        auto* screens = [NSScreen screens];

        Vector<Gfx::IntRect> screen_rects;
        screen_rects.ensure_capacity([screens count]);

        for (id screen in screens) {
            auto screen_rect = ns_rect_to_gfx_rect([screen frame]);
            screen_rects.unchecked_append(screen_rect);
        }

        auto device_pixel_ratio = [[NSScreen mainScreen] backingScaleFactor];

        m_web_view_bridge = MUST(LadybirdWebViewBridge::create(move(screen_rects), device_pixel_ratio));
        [self set_web_view_callbacks];
    }

    return self;
}

#pragma mark - Public methods

- (void)load:(NSString*)url
{
    auto url_string = ns_string_to_string(url);

    if (url_string.starts_with('/'))
        url_string = MUST(String::formatted("file://{}", url_string));
    else if (!URL { url_string }.is_valid())
        url_string = MUST(String::formatted("https://{}", url_string));

    m_web_view_bridge->load(url_string);
}

- (void)handle_resize
{
    auto viewport_rect = ns_rect_to_gfx_rect([self frame]);
    m_web_view_bridge->set_viewport_rect(viewport_rect);
}

#pragma mark - Private methods

- (void)set_web_view_callbacks
{
    m_web_view_bridge->on_ready_to_paint = [self]() {
        [self setNeedsDisplay:YES];
    };

    m_web_view_bridge->on_load_start = [self](auto const& url, bool) {
        auto* ns_url = string_to_ns_string(url.serialize());
        [[self tab_controller] set_location_toolbar_text:ns_url];
    };

    m_web_view_bridge->on_load_finish = [self](auto const& url) {
        auto* ns_url = string_to_ns_string(url.serialize());
        [[self tab_controller] set_location_toolbar_text:ns_url];
    };

    m_web_view_bridge->on_title_change = [self](auto const& title) {
        auto* ns_title = string_to_ns_string(title);
        [[self tab] setTitle:ns_title];
    };
}

- (Tab*)tab
{
    return (Tab*)[self window];
}

- (TabController*)tab_controller
{
    return (TabController*)[[self tab] windowController];
}

#pragma mark - NSView

- (void)drawRect:(NSRect)rect
{
    auto paintable = m_web_view_bridge->paintable();
    if (!paintable.has_value()) {
        [super drawRect:rect];
        return;
    }

    auto [bitmap, bitmap_size] = *paintable;
    VERIFY(bitmap.format() == Gfx::BitmapFormat::BGRA8888);

    static constexpr size_t BITS_PER_COMPONENT = 8;
    static constexpr size_t BITS_PER_PIXEL = 32;
    static constexpr size_t COMPONENTS_PER_PIXEL = 4;

    auto context = [[NSGraphicsContext currentContext] CGContext];
    CGContextSaveGState(context);

    CGContextScaleCTM(context, m_web_view_bridge->inverse_device_pixel_ratio(), m_web_view_bridge->inverse_device_pixel_ratio());

    auto provider = CGDataProviderCreateWithData(nil, bitmap.scanline_u8(0), bitmap.size_in_bytes(), nil);
    auto image_rect = CGRectMake(0, 0, bitmap_size.width(), bitmap_size.height());

    // Ideally, this would be NSBitmapImageRep, but the equivalent factory initWithBitmapDataPlanes: does
    // not seem to actually respect endianness. We need NSBitmapFormatThirtyTwoBitLittleEndian, but the
    // resulting image is always big endian. CGImageCreate actually does respect the endianness.
    auto bitmap_image = CGImageCreate(
        bitmap_size.width(),
        bitmap_size.height(),
        BITS_PER_COMPONENT,
        BITS_PER_PIXEL,
        COMPONENTS_PER_PIXEL * bitmap.width(),
        CGColorSpaceCreateDeviceRGB(),
        kCGBitmapByteOrder32Little | kCGImageAlphaFirst,
        provider,
        nil,
        NO,
        kCGRenderingIntentDefault);

    auto* image = [[NSImage alloc] initWithCGImage:bitmap_image size:NSZeroSize];
    [image drawInRect:image_rect];

    CGContextRestoreGState(context);
    CGImageRelease(bitmap_image);

    [super drawRect:rect];
}

@end
