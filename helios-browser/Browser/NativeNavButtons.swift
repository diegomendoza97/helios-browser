//
//  NativeNavButtons.swift
//  helios-browser
//
//  AppKit-backed navigation buttons to avoid SwiftUI hit-testing issues with embedded CEF views.
//

import AppKit
import SwiftUI

private final class CursorAwareButton: NSButton {
    override var isEnabled: Bool {
        didSet {
            window?.invalidateCursorRects(for: self)
        }
    }

    override func resetCursorRects() {
        discardCursorRects()
        addCursorRect(bounds, cursor: isEnabled ? .pointingHand : .arrow)
    }
}

struct NativeNavButtons: NSViewRepresentable {
    @ObservedObject var store: BrowserStore

    func makeCoordinator() -> Coordinator {
        Coordinator(store: store)
    }

    func makeNSView(context: Context) -> NSStackView {
        let back = CursorAwareButton(image: NSImage(systemSymbolName: "chevron.left", accessibilityDescription: "Back")!, target: context.coordinator, action: #selector(Coordinator.didTapBack))
        back.isBordered = false
        back.bezelStyle = .texturedRounded
        back.setButtonType(.momentaryPushIn)
        back.translatesAutoresizingMaskIntoConstraints = false
        back.widthAnchor.constraint(equalToConstant: 28).isActive = true
        back.heightAnchor.constraint(equalToConstant: 28).isActive = true
        back.toolTip = "Back"

        let forward = CursorAwareButton(image: NSImage(systemSymbolName: "chevron.right", accessibilityDescription: "Forward")!, target: context.coordinator, action: #selector(Coordinator.didTapForward))
        forward.isBordered = false
        forward.bezelStyle = .texturedRounded
        forward.setButtonType(.momentaryPushIn)
        forward.translatesAutoresizingMaskIntoConstraints = false
        forward.widthAnchor.constraint(equalToConstant: 28).isActive = true
        forward.heightAnchor.constraint(equalToConstant: 28).isActive = true
        forward.toolTip = "Forward"

        let reload = CursorAwareButton(image: NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Reload")!, target: context.coordinator, action: #selector(Coordinator.didTapReload))
        reload.isBordered = false
        reload.bezelStyle = .texturedRounded
        reload.setButtonType(.momentaryPushIn)
        reload.translatesAutoresizingMaskIntoConstraints = false
        reload.widthAnchor.constraint(equalToConstant: 28).isActive = true
        reload.heightAnchor.constraint(equalToConstant: 28).isActive = true
        reload.toolTip = "Reload"

        let stack = NSStackView(views: [back, forward, reload])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 4
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        stack.setHuggingPriority(.required, for: .horizontal)

        context.coordinator.backButton = back
        context.coordinator.forwardButton = forward

        updateButtonState(coordinator: context.coordinator)
        return stack
    }

    func updateNSView(_ nsView: NSStackView, context: Context) {
        context.coordinator.store = store
        updateButtonState(coordinator: context.coordinator)
    }

    private func updateButtonState(coordinator: Coordinator) {
        let canBack = store.activeTab?.canGoBack == true
        let canForward = store.activeTab?.canGoForward == true
        coordinator.backButton?.alphaValue = canBack ? 1.0 : 0.45
        coordinator.forwardButton?.alphaValue = canForward ? 1.0 : 0.45
        coordinator.backButton?.isEnabled = canBack
        coordinator.forwardButton?.isEnabled = canForward
    }

    final class Coordinator: NSObject {
        var store: BrowserStore
        weak var backButton: NSButton?
        weak var forwardButton: NSButton?

        init(store: BrowserStore) {
            self.store = store
        }

        @objc func didTapBack() {
            NSLog("[Helios] Native UI back button pressed")
            store.goBack()
        }

        @objc func didTapForward() {
            NSLog("[Helios] Native UI forward button pressed")
            store.goForward()
        }

        @objc func didTapReload() {
            NSLog("[Helios] Native UI reload button pressed")
            store.reload()
        }
    }
}

// MARK: - Sidebar toggle (AppKit; SwiftUI buttons often miss clicks with CEF/WK in-window)

struct NativeSidebarToggleButton: NSViewRepresentable {
    @ObservedObject var store: BrowserStore

    func makeCoordinator() -> Coordinator {
        Coordinator(store: store)
    }

    func makeNSView(context: Context) -> NSButton {
        let image = NSImage(systemSymbolName: "sidebar.leading", accessibilityDescription: "Toggle sidebar")!
        let button = CursorAwareButton(image: image, target: context.coordinator, action: #selector(Coordinator.didToggle))
        button.isBordered = false
        button.bezelStyle = .texturedRounded
        button.setButtonType(.momentaryPushIn)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 28).isActive = true
        button.heightAnchor.constraint(equalToConstant: 28).isActive = true
        button.toolTip = "Toggle sidebar"
        button.contentTintColor = .secondaryLabelColor
        return button
    }

    func updateNSView(_ nsView: NSButton, context: Context) {
        context.coordinator.store = store
    }

    final class Coordinator: NSObject {
        var store: BrowserStore

        init(store: BrowserStore) {
            self.store = store
        }

        @objc func didToggle() {
            store.toggleSideAddressBar()
        }
    }
}
