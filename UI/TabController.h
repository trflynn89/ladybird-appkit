/*
 * Copyright (c) 2023, Tim Flynn <trflynn89@serenityos.org>
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#pragma once

#include <AK/URL.h>

#import <System/Cocoa.h>

@interface TabController : NSWindowController <NSWindowDelegate>

- (instancetype)init:(URL)url;

- (void)focus_location_toolbar_item;
- (void)set_location_toolbar_text:(NSString*)location;

@end
