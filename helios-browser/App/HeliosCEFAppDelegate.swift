//
//  HeliosCEFAppDelegate.swift
//  helios-browser
//
//  Initializes CEF at launch, runs message loop via timer, shuts down on terminate.
//

import AppKit
import Foundation

#if USE_CEF
final class HeliosCEFAppDelegate: NSObject, NSApplicationDelegate {

    private var messageLoopTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        HeliosCEFInitialize()
        messageLoopTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in
            HeliosCEFDoMessageLoopWork()
        }
        RunLoop.main.add(messageLoopTimer!, forMode: .common)
    }

    func applicationWillTerminate(_ notification: Notification) {
        messageLoopTimer?.invalidate()
        messageLoopTimer = nil
        HeliosCEFShutdown()
    }
}
#endif
