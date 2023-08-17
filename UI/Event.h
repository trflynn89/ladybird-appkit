/*
 * Copyright (c) 2023, Tim Flynn <trflynn89@serenityos.org>
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#pragma once

// FIXME: These should not be included outside of Serenity.
#include <Kernel/API/KeyCode.h>
#include <LibGUI/Event.h>

#import <System/Cocoa.h>

struct MouseEvent {
    Gfx::IntPoint position {};
    GUI::MouseButton button { GUI::MouseButton::Primary };
    KeyModifier modifiers { KeyModifier::Mod_None };
};
MouseEvent ns_event_to_mouse_event(NSEvent*, NSView*, GUI::MouseButton);
