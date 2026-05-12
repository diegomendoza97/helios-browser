//
//  AddressBarView.swift
//  helios-browser
//
//  Arc-style address bar: pill shape, minimal chrome.
//

import SwiftUI

struct AddressBarView: View {

    @Binding var urlText: String
    var onSubmit: () -> Void
    var isLoading: Bool
    /// Tighter pill for the side rail (saves vertical space).
    var compact: Bool = false

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: compact ? 8 : 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: compact ? 10 : 11, weight: .medium))
                .foregroundStyle(.secondary)

            TextField("Search or enter URL", text: $urlText)
                .textFieldStyle(.plain)
                .font(.system(size: compact ? 12 : 13))
                .focused($isFocused)
                .onSubmit(onSubmit)

            if isLoading {
                ProgressView()
                    .scaleEffect(compact ? 0.55 : 0.6)
                    .frame(width: 14, height: 14)
            }
        }
        .padding(.horizontal, compact ? 11 : 14)
        .padding(.vertical, compact ? 5 : 8)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.quaternary, lineWidth: 0.5))
    }
}

#Preview {
    VStack(spacing: 16) {
        AddressBarView(
            urlText: .constant("https://apple.com"),
            onSubmit: {},
            isLoading: false
        )
        AddressBarView(
            urlText: .constant("https://apple.com"),
            onSubmit: {},
            isLoading: true,
            compact: true
        )
    }
    .padding()
}
