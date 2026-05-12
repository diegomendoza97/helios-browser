//
//  TitlebarInlineButtonsView.swift
//  helios-browser
//
//  Reparents the system close / minimize / zoom buttons into our toolbar row (Arc-style).
//  When the sidebar is hidden, call `restoreStandardButtons` so controls return to the title bar.
//

import AppKit
import SwiftUI

private struct TitlebarButtonSnapshot {
    weak var superview: NSView?
    var frame: NSRect
}

enum TitlebarInlineButtons {

    private static let types: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
    private static var snapshots: [ObjectIdentifier: TitlebarButtonSnapshot] = [:]

    /// First time we reparent, remember the AppKit title-bar container so we can put buttons back when the sidebar hides.
    private static func captureSnapshotIfNeeded(for button: NSButton) {
        let key = ObjectIdentifier(button)
        guard snapshots[key] == nil, let parent = button.superview else { return }
        snapshots[key] = TitlebarButtonSnapshot(superview: parent, frame: button.frame)
    }

    fileprivate static func embedStandardButtons(in stack: NSStackView) {
        guard let window = stack.window else { return }
        for buttonType in types {
            guard let button = window.standardWindowButton(buttonType) else { continue }
            captureSnapshotIfNeeded(for: button)
            if button.superview !== stack {
                button.removeFromSuperview()
                stack.addArrangedSubview(button)
            }
        }
    }

    /// Moves close / minimize / zoom back into the system title bar (used when the side rail is hidden).
    static func restoreStandardButtons(in window: NSWindow?) {
        guard let window else { return }
        for buttonType in types {
            guard let button = window.standardWindowButton(buttonType) else { continue }
            let key = ObjectIdentifier(button)
            guard let snap = snapshots[key], let parent = snap.superview else { continue }
            if button.superview !== parent {
                button.removeFromSuperview()
                parent.addSubview(button)
                button.frame = snap.frame
            }
        }
        window.contentView?.layoutSubtreeIfNeeded()
        window.layoutIfNeeded()
    }
}

private final class TitlebarButtonStack: NSStackView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        TitlebarInlineButtons.embedStandardButtons(in: self)
    }

    override func layout() {
        super.layout()
        TitlebarInlineButtons.embedStandardButtons(in: self)
    }
}

struct TitlebarInlineButtonsView: NSViewRepresentable {

    func makeNSView(context: Context) -> NSStackView {
        let stack = TitlebarButtonStack()
        stack.orientation = .horizontal
        stack.spacing = 6
        stack.alignment = .centerY
        stack.distribution = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    func updateNSView(_ nsView: NSStackView, context: Context) {
        DispatchQueue.main.async {
            TitlebarInlineButtons.embedStandardButtons(in: nsView)
        }
    }
}
