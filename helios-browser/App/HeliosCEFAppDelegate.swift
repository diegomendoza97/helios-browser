//
//  HeliosCEFAppDelegate.swift
//  helios-browser
//
//  Initializes CEF at launch and pumps CefDoMessageLoopWork on a timer (required for rendering with
//  multi_threaded_message_loop / external_message_pump disabled).
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
        messageLoopTimer?.invalidate()
        messageLoopTimer = nil
        // Defer termination until CEF browsers close; a tight CefDoMessageLoopWork-only loop during
        // applicationWillTerminate blocks the run loop and can prevent OnBeforeClose from firing.
        DispatchQueue.main.async {
            NSLog("[Helios] Starting CEF teardown on main queue (watch for 'CefShutdown returned')")
            HeliosCEFShutdownWithCompletion {
                NSLog("[Helios] CEF teardown finished; allowing app to quit")
                NSApp.reply(toApplicationShouldTerminate: true)
            }
        }
        return .terminateLater
    }

    func applicationWillTerminate(_ notification: Notification) {
        // CEF teardown runs in applicationShouldTerminate (before NSApp.reply). Do not call
        // HeliosCEFShutdown() here — nested CFRunLoop during shutdown can deliver this while still
        // inside HeliosPerformCEFShutdownNow and stall termination (re-entrancy / double CefShutdown).
    }
}
#endif
