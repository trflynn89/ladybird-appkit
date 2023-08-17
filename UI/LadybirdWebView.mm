/*
 * Copyright (c) 2023, Tim Flynn <trflynn89@serenityos.org>
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <AK/Optional.h>
#include <AK/URL.h>
#include <UI/LadybirdWebViewBridge.h>

#import <UI/Event.h>
#import <UI/LadybirdWebView.h>
#import <UI/Tab.h>
#import <UI/TabController.h>
#import <Utilities/Conversions.h>

@interface LadybirdWebView ()
{
    OwnPtr<LadybirdWebViewBridge> m_web_view_bridge;
    Optional<NSTrackingRectTag> m_mouse_tracking_tag;
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
            auto screen_rect = Ladybird::ns_rect_to_gfx_rect([screen frame]);
            screen_rects.unchecked_append(screen_rect);
        }

        auto device_pixel_ratio = [[NSScreen mainScreen] backingScaleFactor];

        m_web_view_bridge = MUST(LadybirdWebViewBridge::create(move(screen_rects), device_pixel_ratio));
        [self set_web_view_callbacks];
    }

    return self;
}

#pragma mark - Public methods

- (void)load:(URL const&)url
{
    m_web_view_bridge->load(url);
}

- (void)handle_resize
{
    [self update_viewport_rect:LadybirdWebViewBridge::ForResize::Yes];
}

- (void)handle_scroll
{
    [self update_viewport_rect:LadybirdWebViewBridge::ForResize::No];
}

#pragma mark - Private methods

- (void)update_viewport_rect:(LadybirdWebViewBridge::ForResize)for_resize
{
    auto content_rect = [self frame];
    auto document_rect = [[self documentView] frame];
    auto device_pixel_ratio = m_web_view_bridge->device_pixel_ratio();

    auto position = [&](auto content_size, auto document_size, auto scroll) {
        return max(0, (document_size - content_size) * device_pixel_ratio * scroll);
    };

    auto horizontal_scroll = [[[self scroll_view] horizontalScroller] floatValue];
    auto vertical_scroll = [[[self scroll_view] verticalScroller] floatValue];

    auto ns_viewport_rect = NSMakeRect(
        position(content_rect.size.width, document_rect.size.width, horizontal_scroll),
        position(content_rect.size.height, document_rect.size.height, vertical_scroll),
        content_rect.size.width,
        content_rect.size.height);

    auto viewport_rect = Ladybird::ns_rect_to_gfx_rect(ns_viewport_rect);
    m_web_view_bridge->set_viewport_rect(viewport_rect, for_resize);
}

- (void)set_web_view_callbacks
{
    m_web_view_bridge->on_layout = [self](auto content_size) {
        auto ns_content_size = Ladybird::gfx_size_to_ns_size(content_size);
        [[self documentView] setFrameSize:ns_content_size];
    };

    m_web_view_bridge->on_ready_to_paint = [self]() {
        [self setNeedsDisplay:YES];
    };

    m_web_view_bridge->on_load_start = [self](auto const& url, bool) {
        auto* ns_url = Ladybird::string_to_ns_string(url.serialize());
        [[self tab_controller] set_location_toolbar_text:ns_url];
    };

    m_web_view_bridge->on_title_change = [self](auto const& title) {
        auto* ns_title = Ladybird::string_to_ns_string(title);
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

- (NSScrollView*)scroll_view
{
    return (NSScrollView*)[self superview];
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

    auto device_pixel_ratio = m_web_view_bridge->device_pixel_ratio();
    auto inverse_device_pixel_ratio = m_web_view_bridge->inverse_device_pixel_ratio();

    CGContextScaleCTM(context, inverse_device_pixel_ratio, inverse_device_pixel_ratio);

    auto provider = CGDataProviderCreateWithData(nil, bitmap.scanline_u8(0), bitmap.size_in_bytes(), nil);
    auto image_rect = CGRectMake(rect.origin.x * device_pixel_ratio, rect.origin.y * device_pixel_ratio, bitmap_size.width(), bitmap_size.height());

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

- (BOOL)isFlipped
{
    // The origin of a NSScrollView is the lower-left corner, with the y-axis extending upwards. Instead,
    // we want the origin to be the top-left corner, with the y-axis extending downward.
    return YES;
}

- (void)updateTrackingAreas
{
    if (m_mouse_tracking_tag.has_value()) {
        [self removeTrackingRect:*m_mouse_tracking_tag];
    }

    m_mouse_tracking_tag = [self addTrackingRect:[self visibleRect]
                                           owner:self
                                        userData:nil
                                    assumeInside:NO];
}

- (void)mouseEntered:(NSEvent*)event
{
    [[self window] setAcceptsMouseMovedEvents:YES];
    [[self window] makeFirstResponder:self];
}

- (void)mouseExited:(NSEvent*)event
{
    [[self window] setAcceptsMouseMovedEvents:NO];
    [[self window] resignFirstResponder];
}

- (void)mouseMoved:(NSEvent*)event
{
    auto [position, button, modifiers] = Ladybird::ns_event_to_mouse_event(event, self, GUI::MouseButton::None);
    m_web_view_bridge->mouse_move_event(position, button, modifiers);
}

- (void)mouseDown:(NSEvent*)event
{
    auto [position, button, modifiers] = Ladybird::ns_event_to_mouse_event(event, self, GUI::MouseButton::Primary);

    if (event.clickCount % 2 == 0) {
        m_web_view_bridge->mouse_double_click_event(position, button, modifiers);
    } else {
        m_web_view_bridge->mouse_down_event(position, button, modifiers);
    }
}

- (void)mouseUp:(NSEvent*)event
{
    auto [position, button, modifiers] = Ladybird::ns_event_to_mouse_event(event, self, GUI::MouseButton::Primary);
    m_web_view_bridge->mouse_up_event(position, button, modifiers);
}

- (void)mouseDragged:(NSEvent*)event
{
    auto [position, button, modifiers] = Ladybird::ns_event_to_mouse_event(event, self, GUI::MouseButton::Primary);
    m_web_view_bridge->mouse_move_event(position, button, modifiers);
}

- (void)rightMouseDown:(NSEvent*)event
{
    auto [position, button, modifiers] = Ladybird::ns_event_to_mouse_event(event, self, GUI::MouseButton::Secondary);

    if (event.clickCount % 2 == 0) {
        m_web_view_bridge->mouse_double_click_event(position, button, modifiers);
    } else {
        m_web_view_bridge->mouse_down_event(position, button, modifiers);
    }
}

- (void)rightMouseUp:(NSEvent*)event
{
    auto [position, button, modifiers] = Ladybird::ns_event_to_mouse_event(event, self, GUI::MouseButton::Secondary);
    m_web_view_bridge->mouse_up_event(position, button, modifiers);
}

- (void)rightMouseDragged:(NSEvent*)event
{
    auto [position, button, modifiers] = Ladybird::ns_event_to_mouse_event(event, self, GUI::MouseButton::Secondary);
    m_web_view_bridge->mouse_move_event(position, button, modifiers);
}

- (void)keyDown:(NSEvent*)event
{
    auto [key_code, modifiers, code_point] = Ladybird::ns_event_to_key_event(event);
    m_web_view_bridge->key_down_event(key_code, modifiers, code_point);
}

- (void)keyUp:(NSEvent*)event
{
    auto [key_code, modifiers, code_point] = Ladybird::ns_event_to_key_event(event);
    m_web_view_bridge->key_up_event(key_code, modifiers, code_point);
}

@end
