//
//  BrowserStore.swift
//  helios-browser
//
//  Centralized state store for browser tabs and navigation.
//

import Combine
import Foundation
import SwiftUI
import WebKit

@MainActor
final class BrowserStore: ObservableObject {
    static let shared = BrowserStore()

    // MARK: - Published State

    @Published private(set) var tabs: [Tab] = []
    @Published private(set) var activeTabID: UUID?
    @Published private(set) var isLoading = false

    /// Left rail: navigation + address bar (Arc-style). Tabs will join this rail later.
    @Published var isSideAddressBarVisible = true

    /// The currently active tab, if any.
    var activeTab: Tab? {
        guard let id = activeTabID else { return nil }
        return tabs.first { $0.id == id }
    }

    // MARK: - Initialization

    init() {
        let defaultTab = Tab(
            title: "",
            url: URL(string: "https://www.apple.com"),
            canGoBack: false,
            canGoForward: false
        )
        tabs = [defaultTab]
        activeTabID = defaultTab.id
    }

    // MARK: - Tab State Updates (called from WebViewCoordinator)

    /// Updates the active tab's URL and title from WebKit.
    func updateTab(id: UUID, url: URL?, title: String?) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        var next = tabs
        if let url = url { next[index].url = url }
        if let title = title, !title.isEmpty { next[index].title = title }
        tabs = next
    }

    /// Updates back/forward state for a tab.
    func updateTab(id: UUID, canGoBack: Bool, canGoForward: Bool) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        var next = tabs
        next[index].canGoBack = canGoBack
        next[index].canGoForward = canGoForward
        tabs = next
    }

    /// Single write for CEF/WK updates so history flags and URL never disagree during rapid SPA navigations.
    func applyTabNavigationState(
        id: UUID,
        url: URL?,
        title: String?,
        canGoBack: Bool,
        canGoForward: Bool,
        loading: Bool
    ) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        var next = tabs
        if let url = url { next[index].url = url }
        if let title = title, !title.isEmpty { next[index].title = title }
        next[index].canGoBack = canGoBack
        next[index].canGoForward = canGoForward
        tabs = next
        isLoading = loading
    }

    /// Sets loading state for the active tab.
    func setLoading(_ loading: Bool) {
        isLoading = loading
    }

    func toggleSideAddressBar() {
        withAnimation(.easeInOut(duration: 0.1)) {
            isSideAddressBarVisible.toggle()
        }
    }

    // MARK: - Navigation Actions

    /// Loads a URL in the active tab (from address bar).
    func loadURL(_ url: URL) {
        guard activeTabID != nil else { return }
        // WebView observes activeTab.url and will load it; we update state first.
        if let index = tabs.firstIndex(where: { $0.id == activeTabID }) {
            var next = tabs
            next[index].url = url
            tabs = next
        }
    }

    /// Navigate back in the active tab.
    func goBack() {
        #if USE_CEF
        if let cef = navigationCEFView ?? currentCEFView?() {
            NSLog("[Helios] Store.goBack tapped")
            cef.navigateBack()
            return
        }
        NSLog("[Helios] goBack: no CEF view (navigationCEFView and currentCEFView are nil)")
        #endif
        currentWebView?()?.goBack()
    }

    /// Navigate forward in the active tab.
    func goForward() {
        #if USE_CEF
        if let cef = navigationCEFView ?? currentCEFView?() {
            NSLog("[Helios] Store.goForward tapped")
            cef.navigateForward()
            return
        }
        NSLog("[Helios] goForward: no CEF view")
        #endif
        currentWebView?()?.goForward()
    }

    /// Reload the active tab.
    func reload() {
        #if USE_CEF
        if let cef = navigationCEFView ?? currentCEFView?() {
            NSLog("[Helios] Store.reload tapped")
            cef.reloadPage()
            return
        }
        NSLog("[Helios] reload: no CEF view")
        #endif
        currentWebView?()?.reload()
    }

    /// Called by BrowserView to provide the current WKWebView for navigation (WebKit build).
    var currentWebView: (() -> WKWebView?)?

    #if USE_CEF
    /// Called by BrowserView to provide the current CEF view for navigation (CEF build).
    var currentCEFView: (() -> HeliosCEFBrowserView?)?

    /// Held strongly so toolbar actions always reach the live view; cleared in `CEFWebView.dismantleNSView`.
    var navigationCEFView: HeliosCEFBrowserView?
    #endif
}
