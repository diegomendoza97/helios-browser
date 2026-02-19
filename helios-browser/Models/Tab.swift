//
//  Tab.swift
//  helios-browser
//
//  Arc-style browser — Tab model.
//

import Foundation

/// Represents a single browser tab with navigation state.
struct Tab: Identifiable, Equatable {
    let id: UUID
    var title: String
    var url: URL?
    var canGoBack: Bool
    var canGoForward: Bool

    init(
        id: UUID = UUID(),
        title: String = "",
        url: URL? = nil,
        canGoBack: Bool = false,
        canGoForward: Bool = false
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.canGoBack = canGoBack
        self.canGoForward = canGoForward
    }
}
