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

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Stop the timer first so no more CEF work is pumped
        messageLoopTimer?.invalidate()
        messageLoopTimer = nil
        return .terminateNow
    }

    func applicationWillTerminate(_ notification: Notification) {
        HeliosCEFShutdown()
    }
}
#endif
