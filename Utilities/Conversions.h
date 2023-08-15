/*
 * Copyright (c) 2023, Tim Flynn <trflynn89@serenityos.org>
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#pragma once

#include <AK/String.h>
#include <AK/StringView.h>
#include <LibGfx/Rect.h>

#import <System/Cocoa.h>

String ns_string_to_string(NSString*);
NSString* string_to_ns_string(StringView);

Gfx::IntRect ns_rect_to_gfx_rect(NSRect);
