//
//  WindowChromeConfigurator.swift
//  helios-browser
//
//  Arc-style window: transparent title bar, hidden title, content under traffic lights.
//

import AppKit
import SwiftUI

struct WindowChromeConfigurator: NSViewRepresentable {

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        view.isHidden = true
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            window.styleMask.insert(.fullSizeContentView)
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.title = ""
            if #available(macOS 11.0, *) {
                window.titlebarSeparatorStyle = .none
            }
        }
    }
}
