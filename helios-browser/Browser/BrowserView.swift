//
//  BrowserView.swift
//  helios-browser
//
//  Arc-inspired layout: compact side rail + framed web panel (rounded, inset).
//

import AppKit
import SwiftUI
import WebKit

struct BrowserView: View {

    @StateObject private var store = BrowserStore.shared
    @State private var addressBarText = ""
    @State private var webViewRef: WKWebView?
    #if USE_CEF
    @State private var cefViewRef: HeliosCEFBrowserView?
    #endif

    private let sideRailWidth: CGFloat = 260
    /// Row height for traffic lights + toggle + 28pt nav buttons.
    private let chromeRowContentHeight: CGFloat = 30

    // MARK: Window title-band (not control sizes)
    /// After reparenting traffic lights into the rail, `safeAreaInsets.top` can stay large; cap so we shrink the title strip, not the buttons.
    private let titlebarTopCap: CGFloat = 18

    // MARK: Web “card” (Arc-style frame)
    private let webPanelInsetSideWithRail: CGFloat = 6
    private let webPanelInsetSideFull: CGFloat = 8
    private let webPanelInsetTopWithRail: CGFloat = 2
    private let webPanelInsetTopFull: CGFloat = 4
    private let webPanelInsetBottomWithRail: CGFloat = 4
    private let webPanelInsetBottomFull: CGFloat = 4
    private let webPanelCornerRadius: CGFloat = 16

    var body: some View {
        GeometryReader { geo in
            let rawTop = geo.safeAreaInsets.top
            let titlebarTop = min(max(rawTop, 4), titlebarTopCap)
            let showRail = store.isSideAddressBarVisible

            HStack(spacing: 0) {
                if showRail {
                    sideAddressRail(titlebarTop: titlebarTop, expandChromeTrailing: true)
                        .frame(width: sideRailWidth)
                        .clipped()
                    Divider().opacity(0.5)
                }
                framedWebPanel(showRail: showRail)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        // Fill the window vertically; ignoring only `.top` left the reader short by any bottom inset / layout guide.
        .ignoresSafeArea(.container, edges: [.top, .bottom])
        .background(WindowChromeConfigurator())
        .onAppear {
            HeliosAppKitApplicationShim.installIsHandlingSendEventIfNeeded()
            BrowserKeyboardShortcutMonitor.installIfNeeded()
            if let url = store.activeTab?.url { addressBarText = url.absoluteString }
            store.currentWebView = { webViewRef }
            #if USE_CEF
            store.currentCEFView = { cefViewRef }
            #endif
        }
        .onChange(of: store.isSideAddressBarVisible) { _, visible in
            if !visible {
                DispatchQueue.main.async {
                    let window = NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first
                    TitlebarInlineButtons.restoreStandardButtons(in: window)
                }
            }
        }
        .onChange(of: store.activeTab?.url) { _, newURL in
            if let u = newURL, u.absoluteString != addressBarText {
                addressBarText = u.absoluteString
            }
        }
    }

    // MARK: - Framed web content (rounded corners + inset like Arc)

    @ViewBuilder
    private func framedWebPanel(showRail: Bool) -> some View {
        let insetSide = showRail ? webPanelInsetSideWithRail : webPanelInsetSideFull
        let insetTop = showRail ? webPanelInsetTopWithRail : webPanelInsetTopFull
        let insetBottom = showRail ? webPanelInsetBottomWithRail : webPanelInsetBottomFull
        // Default ZStack centers children — that vertically letterboxes the web view (huge top/bottom gaps).
        ZStack(alignment: .topLeading) {
            Color(nsColor: .windowBackgroundColor)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            webContentCore(hostCornerRadius: webPanelCornerRadius)
                .padding(.leading, insetSide)
                .padding(.trailing, insetSide)
                .padding(.top, insetTop)
                .padding(.bottom, insetBottom)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .compositingGroup()
                .clipShape(RoundedRectangle(cornerRadius: webPanelCornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: webPanelCornerRadius, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
    }

    @ViewBuilder
    private func webContentCore(hostCornerRadius: CGFloat) -> some View {
        Group {
            if let tab = store.activeTab {
                #if USE_CEF
                CEFWebView(
                    tabID: tab.id,
                    url: tab.url,
                    store: store,
                    cefViewRef: $cefViewRef,
                    hostCornerRadius: hostCornerRadius
                )
                #else
                WebView(
                    tabID: tab.id,
                    url: tab.url,
                    store: store,
                    webViewRef: $webViewRef,
                    hostCornerRadius: hostCornerRadius
                )
                #endif
            } else {
                Color(nsColor: .windowBackgroundColor)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Chrome row (system traffic lights reparented via TitlebarInlineButtonsView)

    @ViewBuilder
    private func chromeControlRow(titlebarTop: CGFloat, expandTrailing: Bool) -> some View {
        HStack(alignment: .center, spacing: 6) {
            TitlebarInlineButtonsView()
                .fixedSize()
            NativeSidebarToggleButton(store: store)
                .frame(height: chromeRowContentHeight)
            NativeNavButtons(store: store)
                .frame(height: chromeRowContentHeight)
            if expandTrailing {
                Spacer(minLength: 0)
            }
        }
        .frame(height: chromeRowContentHeight, alignment: .center)
        .padding(.leading, 6)
        .padding(.trailing, 8)
        .padding(.top, titlebarTop)
    }

    // MARK: - Side rail

    private func sideAddressRail(titlebarTop: CGFloat, expandChromeTrailing: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            chromeControlRow(titlebarTop: titlebarTop, expandTrailing: expandChromeTrailing)
            AddressBarView(
                urlText: $addressBarText,
                onSubmit: submitAddressBar,
                isLoading: store.isLoading,
                compact: false
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.top, 2)
            .padding(.bottom, 4)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: .windowBackgroundColor))
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
