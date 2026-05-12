//
//  HeliosAppKitApplicationShim.swift
//  helios-browser
//
//  SwiftUI replaces NSApplication with a subclass that does not implement `-isHandlingSendEvent`,
//  which Chromium/CEF may call from the message loop. Installing a no-op avoids a crash.
//

import AppKit
import ObjectiveC

enum HeliosAppKitApplicationShim {

    private static var didInstall = false

    /// Call as early as possible (e.g. `applicationWillFinishLaunching` or first `BrowserView.onAppear`).
    static func installIsHandlingSendEventIfNeeded() {
        guard !didInstall else { return }
        guard let appClass = object_getClass(NSApplication.shared) else { return }
        let sel = NSSelectorFromString("isHandlingSendEvent")
        if class_getInstanceMethod(appClass, sel) != nil {
            didInstall = true
            return
        }
        let block: @convention(block) (AnyObject) -> Bool = { _ in false }
        let imp = imp_implementationWithBlock(block)
        guard class_addMethod(appClass, sel, imp, "B@:") else {
            NSLog("[Helios] AppKit shim: class_addMethod(isHandlingSendEvent) failed")
            return
        }
        didInstall = true
        NSLog("[Helios] AppKit shim: added isHandlingSendEvent to %@", NSStringFromClass(appClass))
    }
}
