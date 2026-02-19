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
        }
        .windowStyle(.automatic)
        .defaultSize(width: 1100, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
