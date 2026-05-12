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
    var hostCornerRadius: CGFloat = 0

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsMagnification = true
        webView.setContentHuggingPriority(.defaultLow, for: .vertical)
        webView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        webView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        webView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        webView.wantsLayer = true
        applyLayerCornerRadius(to: webView, radius: hostCornerRadius)
        webViewRef = webView
        if let url = url {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        applyLayerCornerRadius(to: webView, radius: hostCornerRadius)
        guard let newURL = url else { return }
        // Only load if this is a user-driven URL change (e.g. address bar), not every time we get a redirect.
        if webView.url != newURL {
            webView.load(URLRequest(url: newURL))
        }
    }

    private func applyLayerCornerRadius(to webView: WKWebView, radius: CGFloat) {
        guard let layer = webView.layer else { return }
        if radius > 0.5 {
            layer.cornerRadius = radius
            layer.cornerCurve = .continuous
            layer.masksToBounds = true
        } else {
            layer.cornerRadius = 0
            layer.masksToBounds = true
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
        store.applyTabNavigationState(
            id: tabID,
            url: webView.url,
            title: webView.title,
            canGoBack: webView.canGoBack,
            canGoForward: webView.canGoForward,
            loading: false
        )
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        store.applyTabNavigationState(
            id: tabID,
            url: webView.url,
            title: webView.title,
            canGoBack: webView.canGoBack,
            canGoForward: webView.canGoForward,
            loading: false
        )
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        store.setLoading(false)
    }
}
