/*
 * Copyright (c) 2023, Tim Flynn <trflynn89@serenityos.org>
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#import <Application/ApplicationDelegate.h>
#import <UI/Tab.h>
#import <UI/TabController.h>

#if !__has_feature(objc_arc)
#    error "This project requires ARC"
#endif

int main()
{
    [NSApplication sharedApplication];

    [NSApp setDelegate:[[ApplicationDelegate alloc] init]];
    [NSApp activateIgnoringOtherApps:YES];
    [NSApp run];

    return 0;
}
