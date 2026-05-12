//
//  CEFWebView.swift
//  helios-browser
//
//  SwiftUI wrapper around HeliosCEFBrowserView (CEF/Chromium engine).
//

#if USE_CEF
import SwiftUI
import AppKit

struct CEFWebView: NSViewRepresentable {

    let tabID: UUID
    let url: URL?
    let store: BrowserStore
    @Binding var cefViewRef: HeliosCEFBrowserView?
    /// AppKit clips CEF’s composited output; SwiftUI `clipShape` alone often leaves square bottom corners.
    var hostCornerRadius: CGFloat = 0

    func makeNSView(context: Context) -> HeliosCEFBrowserView {
        let view = HeliosCEFBrowserView(frame: .zero)
        // Prevent CEF child NSView from spilling outside this host and stealing toolbar hit-testing.
        view.wantsLayer = true
        view.layer?.masksToBounds = true
        Self.applyLayerCornerRadius(to: view, radius: hostCornerRadius)
        view.autoresizesSubviews = true
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.delegate = context.coordinator
        // Target for toolbar navigation immediately (makeNSView runs on the main thread).
        store.navigationCEFView = view
        // Defer @State binding update to avoid "Modifying state during view update"
        DispatchQueue.main.async {
            cefViewRef = view
        }
        if let url = url {
            view.load(url)
            context.coordinator.lastLoadedURL = url
        }
        return view
    }

    func updateNSView(_ view: HeliosCEFBrowserView, context: Context) {
        Self.applyLayerCornerRadius(to: view, radius: hostCornerRadius)
        guard let newURL = url else { return }
        if newURL != context.coordinator.lastLoadedURL {
            view.load(newURL)
            context.coordinator.lastLoadedURL = newURL
        }
    }

    private static func applyLayerCornerRadius(to view: NSView, radius: CGFloat) {
        guard let layer = view.layer else { return }
        if radius > 0.5 {
            layer.cornerRadius = radius
            layer.cornerCurve = .continuous
            layer.masksToBounds = true
        } else {
            layer.cornerRadius = 0
            layer.masksToBounds = true
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(store: store, tabID: tabID)
    }

    static func dismantleNSView(_ nsView: HeliosCEFBrowserView, coordinator: Coordinator) {
        DispatchQueue.main.async {
            if coordinator.store.navigationCEFView === nsView {
                coordinator.store.navigationCEFView = nil
            }
        }
    }

    class Coordinator: NSObject, HeliosCEFBrowserViewDelegate {
        let store: BrowserStore
        let tabID: UUID
        var lastLoadedURL: URL?

        init(store: BrowserStore, tabID: UUID) {
            self.store = store
            self.tabID = tabID
        }

        func cefBrowserView(_ view: NSView, didLoad url: URL?, title: String, canGoBack: Bool, canGoForward: Bool, loading: Bool) {
            if let url = url {
                lastLoadedURL = url
            }
            store.applyTabNavigationState(
                id: tabID,
                url: url,
                title: title.isEmpty ? nil : title,
                canGoBack: canGoBack,
                canGoForward: canGoForward,
                loading: loading
            )
        }
    }
}
#endif
