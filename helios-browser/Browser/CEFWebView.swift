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

    func makeNSView(context: Context) -> HeliosCEFBrowserView {
        let view = HeliosCEFBrowserView(frame: .zero)
        view.delegate = context.coordinator
        // Defer binding update to avoid "Modifying state during view update"
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
        guard let newURL = url else { return }
        if newURL != context.coordinator.lastLoadedURL {
            view.load(newURL)
            context.coordinator.lastLoadedURL = newURL
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(store: store, tabID: tabID)
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
            Task { @MainActor in
                store.updateTab(id: tabID, url: url, title: title.isEmpty ? nil : title)
                store.updateTab(id: tabID, canGoBack: canGoBack, canGoForward: canGoForward)
                store.setLoading(loading)
            }
        }
    }
}
#endif
