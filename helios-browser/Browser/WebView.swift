//
//  WebView.swift
//  helios-browser
//
//  WKWebView wrapped in NSViewRepresentable with Coordinator for navigation delegate.
//

import SwiftUI
import WebKit

// MARK: - WebView (NSViewRepresentable)

struct WebView: NSViewRepresentable {

    let tabID: UUID
    let url: URL?
    let store: BrowserStore
    @Binding var webViewRef: WKWebView?

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsMagnification = true
        webView.wantsLayer = true
        webViewRef = webView
        if let url = url {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard let newURL = url else { return }
        // Only load if this is a user-driven URL change (e.g. address bar), not every time we get a redirect.
        if webView.url != newURL {
            webView.load(URLRequest(url: newURL))
        }
    }

    func makeCoordinator() -> WebViewCoordinator {
        WebViewCoordinator(tabID: tabID, store: store)
    }
}

// MARK: - WebViewCoordinator (WKNavigationDelegate)

final class WebViewCoordinator: NSObject, WKNavigationDelegate {

    let tabID: UUID
    let store: BrowserStore

    init(tabID: UUID, store: BrowserStore) {
        self.tabID = tabID
        self.store = store
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        store.setLoading(true)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        store.setLoading(false)
        store.updateTab(id: tabID, url: webView.url, title: webView.title)
        store.updateTab(id: tabID, canGoBack: webView.canGoBack, canGoForward: webView.canGoForward)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        store.setLoading(false)
        store.updateTab(id: tabID, canGoBack: webView.canGoBack, canGoForward: webView.canGoForward)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        store.setLoading(false)
    }
}
