/*
 * Copyright (c) 2023, Tim Flynn <trflynn89@serenityos.org>
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#pragma once

#include <AK/URL.h>

#import <System/Cocoa.h>

@class LadybirdWebView;

@interface Tab : NSWindow

- (instancetype)init:(URL)url;

@property (nonatomic, strong) LadybirdWebView* web_view;

@end
