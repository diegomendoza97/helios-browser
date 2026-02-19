# Web engine options for Helios

## Current: WebKit (WKWebView)

Helios uses **WebKit** via `WKWebView` — the same engine used by Safari on macOS and iOS. It’s the standard, supported way to show web content in a native Apple app and works well with SwiftUI.

## Using Chromium (Chrome’s engine) on macOS

If you want **Chromium/Blink** (Chrome’s engine) instead of WebKit, you have two main options:

### 1. Chromium Embedded Framework (CEF)

- **What it is:** A C++ framework that embeds Chromium in your app.
- **Pros:** Full Chromium behavior and compatibility.
- **Cons:** Large dependency, C++ build and toolchain, more complex integration with Swift (via C++ or Objective-C wrappers). You’d typically add a CEF target or use a community Swift/CEF wrapper.

### 2. Electron-style app

- **What it is:** Build the UI with web tech and run it in Electron (which uses Chromium).
- **Cons:** No longer a native Swift/SwiftUI app; different architecture and distribution model.

## Recommendation

For a **native, Swift/SwiftUI** browser with a custom UI:

- **Stick with WebKit** for the best balance of simplicity, performance, and system integration. Most sites work the same in Safari and Chrome; the main differences are in dev tools and a few proprietary features.
- Consider **CEF** only if you have a hard requirement for Chromium-specific behavior or rendering.

The entitlement `com.apple.security.network.client` has been added so WKWebView can load pages from the network. After a clean build and run, the address bar should load and render URLs (e.g. https://apple.com).
