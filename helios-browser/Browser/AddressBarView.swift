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

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            TextField("Search or enter URL", text: $urlText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($isFocused)
                .onSubmit(onSubmit)

            if isLoading {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 14, height: 14)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.quaternary, lineWidth: 0.5))
    }
}

#Preview {
    AddressBarView(
        urlText: .constant("https://apple.com"),
        onSubmit: {},
        isLoading: false
    )
    .padding()
}
