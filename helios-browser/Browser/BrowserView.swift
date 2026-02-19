//
//  BrowserView.swift
//  helios-browser
//
//  Arc-inspired layout: minimal toolbar, address bar, content.
//

import SwiftUI
import WebKit

struct BrowserView: View {

    @StateObject private var store = BrowserStore()
    @State private var addressBarText = ""
    @State private var webViewRef: WKWebView?
    #if USE_CEF
    @State private var cefViewRef: HeliosCEFBrowserView?
    #endif

    private let toolbarHeight: CGFloat = 44
    private let backForwardSize: CGFloat = 28

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
                .opacity(0.5)
            webContent
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            if let url = store.activeTab?.url { addressBarText = url.absoluteString }
            store.currentWebView = { webViewRef }
            #if USE_CEF
            store.currentCEFView = { cefViewRef }
            #endif
        }
        .onChange(of: store.activeTab?.url) { _, newURL in
            if let u = newURL, u.absoluteString != addressBarText {
                addressBarText = u.absoluteString
            }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 6) {
            backForwardButtons
            addressBar
            Spacer(minLength: 8)
        }
        .padding(.horizontal, 12)
        .frame(height: toolbarHeight)
    }

    private var backForwardButtons: some View {
        HStack(spacing: 2) {
            Button {
                store.goBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: backForwardSize, height: backForwardSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(store.activeTab?.canGoBack != true)

            Button {
                store.goForward()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: backForwardSize, height: backForwardSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(store.activeTab?.canGoForward != true)

            Button {
                store.reload()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: backForwardSize, height: backForwardSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(store.activeTab?.canGoBack == true ? .primary : .secondary)
    }

    private var addressBar: some View {
        AddressBarView(
            urlText: $addressBarText,
            onSubmit: submitAddressBar,
            isLoading: store.isLoading
        )
        .frame(maxWidth: 560)
    }

    private var webContent: some View {
        Group {
            if let tab = store.activeTab {
                #if USE_CEF
                CEFWebView(
                    tabID: tab.id,
                    url: tab.url,
                    store: store,
                    cefViewRef: $cefViewRef
                )
                #else
                WebView(
                    tabID: tab.id,
                    url: tab.url,
                    store: store,
                    webViewRef: $webViewRef
                )
                #endif
            } else {
                Color(nsColor: .windowBackgroundColor)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func submitAddressBar() {
        let trimmed = addressBarText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var urlString = trimmed
        if !urlString.contains(".") || urlString.contains(" ") {
            urlString = "https://www.google.com/search?q=\(urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed)"
        } else if !urlString.hasPrefix("http") {
            urlString = "https://\(urlString)"
        }
        if let url = URL(string: urlString) {
            store.loadURL(url)
        }
    }
}

#Preview {
    BrowserView()
        .frame(width: 900, height: 600)
}
