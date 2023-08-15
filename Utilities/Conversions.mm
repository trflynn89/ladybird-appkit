/*
 * Copyright (c) 2023, Tim Flynn <trflynn89@serenityos.org>
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#import <Utilities/Conversions.h>

String ns_string_to_string(NSString* string)
{
    auto const* utf8 = [string UTF8String];
    return MUST(String::from_utf8({ utf8, strlen(utf8) }));
}

NSString* string_to_ns_string(StringView string)
{
    auto* data = [NSData dataWithBytes:string.characters_without_null_termination() length:string.length()];
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

Gfx::IntRect ns_rect_to_gfx_rect(NSRect rect)
{
    return {
        static_cast<int>(rect.origin.x),
        static_cast<int>(rect.origin.y),
        static_cast<int>(rect.size.width),
        static_cast<int>(rect.size.height),
    };
}
