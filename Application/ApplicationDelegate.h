/*
 * Copyright (c) 2023, Tim Flynn <trflynn89@serenityos.org>
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#pragma once

#include <AK/Optional.h>
#include <AK/URL.h>
#include <Browser/CookieJar.h>

#import <System/Cocoa.h>

@class Tab;
@class TabController;

@interface ApplicationDelegate : NSObject <NSApplicationDelegate>

- (nullable instancetype)init:(Optional<URL>)initial_url
                withCookieJar:(Browser::CookieJar)cookie_jar;

- (nonnull TabController*)createNewTab:(Optional<URL> const&)url;
- (void)removeTab:(nonnull TabController*)controller;

- (Browser::CookieJar&)cookieJar;

@end
