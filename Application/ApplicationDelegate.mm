/*
 * Copyright (c) 2023, Tim Flynn <trflynn89@serenityos.org>
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <BrowserSettings/Defaults.h>

#import <Application/ApplicationDelegate.h>
#import <UI/Tab.h>
#import <UI/TabController.h>
#import <Utilities/URL.h>

#if !__has_feature(objc_arc)
#    error "This project requires ARC"
#endif

@interface ApplicationDelegate ()
{
    Optional<URL> m_initial_url;
    URL m_new_tab_page_url;
}

@property (nonatomic, strong) NSMutableArray<TabController*>* managed_tabs;

- (NSMenuItem*)create_application_menu;
- (NSMenuItem*)create_file_menu;
- (NSMenuItem*)create_edit_menu;
- (NSMenuItem*)create_view_menu;
- (NSMenuItem*)create_windows_menu;
- (NSMenuItem*)create_help_menu;

@end

@implementation ApplicationDelegate

- (instancetype)init:(Optional<URL>)initial_url
{
    if (self = [super init]) {
        [NSApp setMainMenu:[[NSMenu alloc] init]];

        [[NSApp mainMenu] addItem:[self create_application_menu]];
        [[NSApp mainMenu] addItem:[self create_file_menu]];
        [[NSApp mainMenu] addItem:[self create_edit_menu]];
        [[NSApp mainMenu] addItem:[self create_view_menu]];
        [[NSApp mainMenu] addItem:[self create_windows_menu]];
        [[NSApp mainMenu] addItem:[self create_help_menu]];

        self.managed_tabs = [[NSMutableArray alloc] init];

        m_initial_url = move(initial_url);
        m_new_tab_page_url = Ladybird::rebase_url_on_serenity_resource_root(Browser::default_new_tab_url);
    }

    return self;
}

#pragma mark - Public methods

- (TabController*)create_new_tab:(Optional<URL> const&)url
{
    // This handle must be acquired before creating the new tab.
    auto* current_tab = (Tab*)[NSApp keyWindow];

    auto* controller = [[TabController alloc] init:url.value_or(m_new_tab_page_url)];
    [controller showWindow:nil];

    if (current_tab) {
        [current_tab addTabbedWindow:controller.window ordered:NSWindowAbove];
    }

    [self.managed_tabs addObject:controller];
    return controller;
}

- (void)remove_tab:(TabController*)controller
{
    [self.managed_tabs removeObject:controller];
}

#pragma mark - Private methods

- (void)close_current_tab:(id)sender
{
    auto* current_tab = (Tab*)[NSApp keyWindow];
    [current_tab close];
}

- (void)open_location:(id)sender
{
    auto* current_tab = (Tab*)[NSApp keyWindow];
    auto* controller = (TabController*)[current_tab windowController];
    [controller focus_location_toolbar_item];
}

- (NSMenuItem*)create_application_menu
{
    auto* menu = [[NSMenuItem alloc] init];

    auto* process_name = [[NSProcessInfo processInfo] processName];
    auto* submenu = [[NSMenu alloc] initWithTitle:process_name];

    [submenu addItem:[[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"About %@", process_name]
                                                action:@selector(orderFrontStandardAboutPanel:)
                                         keyEquivalent:@""]];
    [submenu addItem:[NSMenuItem separatorItem]];

    [submenu addItem:[[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"Hide %@", process_name]
                                                action:@selector(hide:)
                                         keyEquivalent:@"h"]];
    [submenu addItem:[NSMenuItem separatorItem]];

    [submenu addItem:[[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"Quit %@", process_name]
                                                action:@selector(terminate:)
                                         keyEquivalent:@"q"]];

    [menu setSubmenu:submenu];
    return menu;
}

- (NSMenuItem*)create_file_menu
{
    auto* menu = [[NSMenuItem alloc] init];
    auto* submenu = [[NSMenu alloc] initWithTitle:@"File"];

    [submenu addItem:[[NSMenuItem alloc] initWithTitle:@"New Tab"
                                                action:@selector(create_new_tab:)
                                         keyEquivalent:@"t"]];
    [submenu addItem:[[NSMenuItem alloc] initWithTitle:@"Close Tab"
                                                action:@selector(close_current_tab:)
                                         keyEquivalent:@"w"]];
    [submenu addItem:[NSMenuItem separatorItem]];

    [submenu addItem:[[NSMenuItem alloc] initWithTitle:@"Open Location"
                                                action:@selector(open_location:)
                                         keyEquivalent:@"l"]];

    [menu setSubmenu:submenu];
    return menu;
}

- (NSMenuItem*)create_edit_menu
{
    auto* menu = [[NSMenuItem alloc] init];
    auto* submenu = [[NSMenu alloc] initWithTitle:@"Edit"];

    [submenu addItem:[[NSMenuItem alloc] initWithTitle:@"Undo"
                                                action:@selector(undo:)
                                         keyEquivalent:@"z"]];
    [submenu addItem:[[NSMenuItem alloc] initWithTitle:@"Redo"
                                                action:@selector(redo:)
                                         keyEquivalent:@"y"]];
    [submenu addItem:[NSMenuItem separatorItem]];

    [submenu addItem:[[NSMenuItem alloc] initWithTitle:@"Cut"
                                                action:@selector(cut:)
                                         keyEquivalent:@"x"]];
    [submenu addItem:[[NSMenuItem alloc] initWithTitle:@"Copy"
                                                action:@selector(copy:)
                                         keyEquivalent:@"c"]];
    [submenu addItem:[[NSMenuItem alloc] initWithTitle:@"Paste"
                                                action:@selector(paste:)
                                         keyEquivalent:@"v"]];
    [submenu addItem:[NSMenuItem separatorItem]];

    [submenu addItem:[[NSMenuItem alloc] initWithTitle:@"Select all"
                                                action:@selector(selectAll:)
                                         keyEquivalent:@"a"]];

    [menu setSubmenu:submenu];
    return menu;
}

- (NSMenuItem*)create_view_menu
{
    auto* menu = [[NSMenuItem alloc] init];
    auto* submenu = [[NSMenu alloc] initWithTitle:@"View"];

    [menu setSubmenu:submenu];
    return menu;
}

- (NSMenuItem*)create_windows_menu
{
    auto* menu = [[NSMenuItem alloc] init];
    auto* submenu = [[NSMenu alloc] initWithTitle:@"Windows"];

    [NSApp setWindowsMenu:submenu];

    [menu setSubmenu:submenu];
    return menu;
}

- (NSMenuItem*)create_help_menu
{
    auto* menu = [[NSMenuItem alloc] init];
    auto* submenu = [[NSMenu alloc] initWithTitle:@"Help"];

    [NSApp setHelpMenu:submenu];

    [menu setSubmenu:submenu];
    return menu;
}

#pragma mark - NSApplicationDelegate

- (void)applicationDidFinishLaunching:(NSNotification*)notification
{
    [self create_new_tab:m_initial_url];
}

- (void)applicationWillTerminate:(NSNotification*)notification
{
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)sender
{
    return YES;
}

@end
