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

    // MARK: - Published State

    @Published private(set) var tabs: [Tab] = []
    @Published private(set) var activeTabID: UUID?
    @Published private(set) var isLoading = false

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
        if let url = url { tabs[index].url = url }
        if let title = title, !title.isEmpty { tabs[index].title = title }
    }

    /// Updates back/forward state for a tab.
    func updateTab(id: UUID, canGoBack: Bool, canGoForward: Bool) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[index].canGoBack = canGoBack
        tabs[index].canGoForward = canGoForward
    }

    /// Sets loading state for the active tab.
    func setLoading(_ loading: Bool) {
        isLoading = loading
    }

    // MARK: - Navigation Actions

    /// Loads a URL in the active tab (from address bar).
    func loadURL(_ url: URL) {
        guard activeTabID != nil else { return }
        // WebView observes activeTab.url and will load it; we update state first.
        if let index = tabs.firstIndex(where: { $0.id == activeTabID }) {
            tabs[index].url = url
        }
    }

    /// Navigate back in the active tab.
    func goBack() {
        #if USE_CEF
        if let cef = currentCEFView?() {
            cef.goBack()
            return
        }
        #endif
        currentWebView?()?.goBack()
    }

    /// Navigate forward in the active tab.
    func goForward() {
        #if USE_CEF
        if let cef = currentCEFView?() {
            cef.goForward()
            return
        }
        #endif
        currentWebView?()?.goForward()
    }

    /// Reload the active tab.
    func reload() {
        #if USE_CEF
        if let cef = currentCEFView?() {
            cef.reload()
            return
        }
        #endif
        currentWebView?()?.reload()
    }

    /// Called by BrowserView to provide the current WKWebView for navigation (WebKit build).
    var currentWebView: (() -> WKWebView?)?

    #if USE_CEF
    /// Called by BrowserView to provide the current CEF view for navigation (CEF build).
    var currentCEFView: (() -> HeliosCEFBrowserView?)?
    #endif
}
