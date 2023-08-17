/*
 * Copyright (c) 2023, Tim Flynn <trflynn89@serenityos.org>
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#import <UI/Event.h>
#import <Utilities/Conversions.h>

namespace Ladybird {

MouseEvent ns_event_to_mouse_event(NSEvent* event, NSView* view, GUI::MouseButton button)
{
    auto position = [view convertPoint:event.locationInWindow fromView:nil];
    unsigned modifiers = Mod_None;

    if ((event.modifierFlags & NSEventModifierFlagShift) != 0) {
        modifiers |= Mod_Shift;
    }
    if ((event.modifierFlags & NSEventModifierFlagControl) != 0) {
        if (button == GUI::MouseButton::Primary) {
            button = GUI::MouseButton::Secondary;
        } else {
            modifiers |= Mod_Ctrl;
        }
    }
    if ((event.modifierFlags & NSEventModifierFlagOption) != 0) {
        modifiers |= Mod_Alt;
    }
    if ((event.modifierFlags & NSEventModifierFlagCommand) != 0) {
        modifiers |= Mod_Super;
    }

    return { ns_point_to_gfx_point(position), button, static_cast<KeyModifier>(modifiers) };
}

}
