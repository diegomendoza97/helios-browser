//
//  helios_browserApp.swift
//  helios-browser
//
//  Created by Diego Mendoza on 2/18/26.
//

import SwiftUI

@main
struct helios_browserApp: App {
    #if USE_CEF
    @NSApplicationDelegateAdaptor(HeliosCEFAppDelegate.self) var cefAppDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            BrowserView()
                .frame(minWidth: 800, minHeight: 500)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .defaultSize(width: 1100, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandMenu("View") {
                Button("Toggle Address Bar Sidebar") {
                    BrowserStore.shared.toggleSideAddressBar()
                }
                .keyboardShortcut("s", modifiers: .command)
            }
            CommandMenu("Navigation") {
                Button("Back") {
                    NSLog("[Helios] Menu Back selected")
                    BrowserStore.shared.goBack()
                }
                .keyboardShortcut("[", modifiers: .command)

                Button("Forward") {
                    NSLog("[Helios] Menu Forward selected")
                    BrowserStore.shared.goForward()
                }
                .keyboardShortcut("]", modifiers: .command)

                Button("Reload") {
                    NSLog("[Helios] Menu Reload selected")
                    BrowserStore.shared.reload()
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}
