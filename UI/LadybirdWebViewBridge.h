/*
 * Copyright (c) 2023, Tim Flynn <trflynn89@serenityos.org>
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#pragma once

#include <AK/Vector.h>
#include <LibGfx/Rect.h>
#include <LibWebView/ViewImplementation.h>

class LadybirdWebViewBridge final : public WebView::ViewImplementation {
public:
    static ErrorOr<NonnullOwnPtr<LadybirdWebViewBridge>> create(Vector<Gfx::IntRect> screen_rects, float device_pixel_ratio);
    virtual ~LadybirdWebViewBridge() override;

    float device_pixel_ratio() const { return m_device_pixel_ratio; }
    float inverse_device_pixel_ratio() const { return m_inverse_device_pixel_ratio; }

    void set_viewport_rect(Gfx::IntRect);

    struct Paintable {
        Gfx::Bitmap& bitmap;
        Gfx::IntSize bitmap_size;
    };
    Optional<Paintable> paintable();
    Function<void()> on_ready_to_paint;

private:
    LadybirdWebViewBridge(Vector<Gfx::IntRect> screen_rects, float device_pixel_ratio);

    virtual void notify_server_did_layout(Badge<WebView::WebContentClient>, Gfx::IntSize content_size) override;
    virtual void notify_server_did_paint(Badge<WebView::WebContentClient>, i32 bitmap_id, Gfx::IntSize) override;
    virtual void notify_server_did_invalidate_content_rect(Badge<WebView::WebContentClient>, Gfx::IntRect const&) override;
    virtual void notify_server_did_change_selection(Badge<WebView::WebContentClient>) override;
    virtual void notify_server_did_request_cursor_change(Badge<WebView::WebContentClient>, Gfx::StandardCursor cursor) override;
    virtual void notify_server_did_request_scroll(Badge<WebView::WebContentClient>, i32, i32) override;
    virtual void notify_server_did_request_scroll_to(Badge<WebView::WebContentClient>, Gfx::IntPoint) override;
    virtual void notify_server_did_request_scroll_into_view(Badge<WebView::WebContentClient>, Gfx::IntRect const&) override;
    virtual void notify_server_did_enter_tooltip_area(Badge<WebView::WebContentClient>, Gfx::IntPoint, DeprecatedString const&) override;
    virtual void notify_server_did_leave_tooltip_area(Badge<WebView::WebContentClient>) override;
    virtual void notify_server_did_request_alert(Badge<WebView::WebContentClient>, String const& message) override;
    virtual void notify_server_did_request_confirm(Badge<WebView::WebContentClient>, String const& message) override;
    virtual void notify_server_did_request_prompt(Badge<WebView::WebContentClient>, String const& message, String const& default_) override;
    virtual void notify_server_did_request_set_prompt_text(Badge<WebView::WebContentClient>, String const& message) override;
    virtual void notify_server_did_request_accept_dialog(Badge<WebView::WebContentClient>) override;
    virtual void notify_server_did_request_dismiss_dialog(Badge<WebView::WebContentClient>) override;
    virtual void notify_server_did_request_file(Badge<WebView::WebContentClient>, DeprecatedString const& path, i32) override;
    virtual void notify_server_did_finish_handling_input_event(bool event_was_accepted) override;

    virtual void update_zoom() override;
    virtual Gfx::IntRect viewport_rect() const override;
    virtual Gfx::IntPoint to_content_position(Gfx::IntPoint widget_position) const override;
    virtual Gfx::IntPoint to_widget_position(Gfx::IntPoint content_position) const override;

    virtual void create_client(WebView::EnableCallgrindProfiling) override;

    void update_palette();

    Vector<Gfx::IntRect> m_screen_rects;
    Gfx::IntRect m_viewport_rect;

    float m_inverse_device_pixel_ratio { 1.0 };
};
