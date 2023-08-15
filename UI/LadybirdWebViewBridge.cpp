/*
 * Copyright (c) 2023, Tim Flynn <trflynn89@serenityos.org>
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <Ladybird/HelperProcess.h>
#include <Ladybird/Types.h>
#include <Ladybird/Utilities.h>
#include <LibCore/File.h>
#include <LibGfx/Font/FontDatabase.h>
#include <LibGfx/Rect.h>
#include <LibIPC/File.h>
#include <LibWeb/Crypto/Crypto.h>
#include <UI/LadybirdWebViewBridge.h>

ErrorOr<NonnullOwnPtr<LadybirdWebViewBridge>> LadybirdWebViewBridge::create(Vector<Gfx::IntRect> screen_rects)
{
    return adopt_nonnull_own_or_enomem(new (nothrow) LadybirdWebViewBridge(move(screen_rects)));
}

LadybirdWebViewBridge::LadybirdWebViewBridge(Vector<Gfx::IntRect> screen_rects)
    : m_screen_rects(move(screen_rects))
{
    create_client(WebView::EnableCallgrindProfiling::No);
}

LadybirdWebViewBridge::~LadybirdWebViewBridge() = default;

void LadybirdWebViewBridge::set_viewport_rect(Gfx::IntRect rect)
{
    m_viewport_rect = rect;
    client().async_set_viewport_rect(rect);
    handle_resize();
    request_repaint();
}

Optional<LadybirdWebViewBridge::Paintable> LadybirdWebViewBridge::paintable()
{
    Gfx::Bitmap* bitmap = nullptr;
    Gfx::IntSize bitmap_size;

    if (m_client_state.has_usable_bitmap) {
        bitmap = m_client_state.front_bitmap.bitmap.ptr();
        bitmap_size = m_client_state.front_bitmap.last_painted_size;
    } else {
        bitmap = m_backup_bitmap.ptr();
        bitmap_size = m_backup_bitmap_size;
    }

    if (!bitmap)
        return {};
    return Paintable { *bitmap, bitmap_size };
}

void LadybirdWebViewBridge::notify_server_did_layout(Badge<WebView::WebContentClient>, Gfx::IntSize)
{
}

void LadybirdWebViewBridge::notify_server_did_paint(Badge<WebView::WebContentClient>, i32 bitmap_id, Gfx::IntSize size)
{
    if (m_client_state.back_bitmap.id == bitmap_id) {
        m_client_state.has_usable_bitmap = true;
        m_client_state.back_bitmap.pending_paints--;
        m_client_state.back_bitmap.last_painted_size = size;
        swap(m_client_state.back_bitmap, m_client_state.front_bitmap);
        // We don't need the backup bitmap anymore, so drop it.
        m_backup_bitmap = nullptr;

        if (on_ready_to_paint)
            on_ready_to_paint();

        if (m_client_state.got_repaint_requests_while_painting) {
            m_client_state.got_repaint_requests_while_painting = false;
            request_repaint();
        }
    }
}

void LadybirdWebViewBridge::notify_server_did_invalidate_content_rect(Badge<WebView::WebContentClient>, Gfx::IntRect const&)
{
    request_repaint();
}

void LadybirdWebViewBridge::notify_server_did_change_selection(Badge<WebView::WebContentClient>)
{
    request_repaint();
}

void LadybirdWebViewBridge::notify_server_did_request_cursor_change(Badge<WebView::WebContentClient>, Gfx::StandardCursor)
{
}

void LadybirdWebViewBridge::notify_server_did_request_scroll(Badge<WebView::WebContentClient>, i32, i32)
{
}

void LadybirdWebViewBridge::notify_server_did_request_scroll_to(Badge<WebView::WebContentClient>, Gfx::IntPoint)
{
}

void LadybirdWebViewBridge::notify_server_did_request_scroll_into_view(Badge<WebView::WebContentClient>, Gfx::IntRect const&)
{
}

void LadybirdWebViewBridge::notify_server_did_enter_tooltip_area(Badge<WebView::WebContentClient>, Gfx::IntPoint, DeprecatedString const&)
{
}

void LadybirdWebViewBridge::notify_server_did_leave_tooltip_area(Badge<WebView::WebContentClient>)
{
}

void LadybirdWebViewBridge::notify_server_did_request_alert(Badge<WebView::WebContentClient>, String const&)
{
}

void LadybirdWebViewBridge::notify_server_did_request_confirm(Badge<WebView::WebContentClient>, String const&)
{
}

void LadybirdWebViewBridge::notify_server_did_request_prompt(Badge<WebView::WebContentClient>, String const&, String const&)
{
}

void LadybirdWebViewBridge::notify_server_did_request_set_prompt_text(Badge<WebView::WebContentClient>, String const&)
{
}

void LadybirdWebViewBridge::notify_server_did_request_accept_dialog(Badge<WebView::WebContentClient>)
{
}

void LadybirdWebViewBridge::notify_server_did_request_dismiss_dialog(Badge<WebView::WebContentClient>)
{
}

void LadybirdWebViewBridge::notify_server_did_request_file(Badge<WebView::WebContentClient>, DeprecatedString const& path, i32 request_id)
{
    auto file = Core::File::open(path, Core::File::OpenMode::Read);

    if (file.is_error())
        client().async_handle_file_return(file.error().code(), {}, request_id);
    else
        client().async_handle_file_return(0, IPC::File(*file.value()), request_id);
}

void LadybirdWebViewBridge::notify_server_did_finish_handling_input_event(bool)
{
}

void LadybirdWebViewBridge::update_zoom()
{
}

Gfx::IntRect LadybirdWebViewBridge::viewport_rect() const
{
    return m_viewport_rect;
}

Gfx::IntPoint LadybirdWebViewBridge::to_content_position(Gfx::IntPoint widget_position) const
{
    return widget_position;
}

Gfx::IntPoint LadybirdWebViewBridge::to_widget_position(Gfx::IntPoint content_position) const
{
    return content_position;
}

void LadybirdWebViewBridge::create_client(WebView::EnableCallgrindProfiling enable_callgrind_profiling)
{
    m_client_state = {};

    auto candidate_web_content_paths = MUST(get_paths_for_helper_process("WebContent"sv));
    auto new_client = MUST(launch_web_content_process(*this, candidate_web_content_paths, enable_callgrind_profiling, WebView::IsLayoutTestMode::No, Ladybird::UseLagomNetworking::Yes));

    m_client_state.client = new_client;
    m_client_state.client->on_web_content_process_crash = [this] {
        Core::deferred_invoke([this] {
            handle_web_content_process_crash();
        });
    };

    m_client_state.client_handle = MUST(Web::Crypto::generate_random_uuid());
    client().async_set_window_handle(m_client_state.client_handle);

    client().async_set_device_pixels_per_css_pixel(m_device_pixel_ratio);
    client().async_update_system_fonts(Gfx::FontDatabase::default_font_query(), Gfx::FontDatabase::fixed_width_font_query(), Gfx::FontDatabase::window_title_font_query());
    update_palette();

    if (!m_screen_rects.is_empty()) {
        // FIXME: Update the screens again if they ever change.
        client().async_update_screen_rects(m_screen_rects, 0);
    }
}

void LadybirdWebViewBridge::update_palette()
{
    auto theme = MUST(Gfx::load_system_theme(DeprecatedString::formatted("{}/res/themes/Default.ini", s_serenity_resource_root)));
    auto palette_impl = Gfx::PaletteImpl::create_with_anonymous_buffer(theme);
    auto palette = Gfx::Palette(move(palette_impl));

    client().async_update_system_theme(move(theme));
}
