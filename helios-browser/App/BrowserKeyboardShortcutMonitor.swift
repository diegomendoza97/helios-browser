//
//  BrowserKeyboardShortcutMonitor.swift
//  helios-browser
//
//  CEF (and WKWebView) retain key-window focus, so menu shortcuts for navigation often never fire.
//  A local key monitor runs while the app is active and forwards browser shortcuts to BrowserStore.
//

import AppKit

enum BrowserKeyboardShortcutMonitor {

    private static var localKeyDownMonitor: Any?

    static func installIfNeeded() {
        guard localKeyDownMonitor == nil else { return }
        localKeyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handledBrowserShortcut(event) ? nil : event
        }
    }

    /// Returns true if the event was consumed (navigation invoked).
    private static func handledBrowserShortcut(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.command) else { return false }
        guard !flags.contains(.control) else { return false }

        // Cmd+[ and Cmd+] (Safari-style), plus Cmd+← / Cmd+→.
        let keyCode = Int(event.keyCode)
        // 123 = left arrow, 124 = right arrow
        if keyCode == 123 {
            BrowserStore.shared.goBack()
            return true
        }
        if keyCode == 124 {
            BrowserStore.shared.goForward()
            return true
        }

        guard let chars = event.charactersIgnoringModifiers, let scalar = chars.unicodeScalars.first else {
            return false
        }
        let code = Int(scalar.value)
        // Bracket keys (US and many layouts): [ = 0x5B, ] = 0x5D
        if code == 0x5B {
            BrowserStore.shared.goBack()
            return true
        }
        if code == 0x5D {
            BrowserStore.shared.goForward()
            return true
        }
        return false
    }
}
