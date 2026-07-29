//
//  ActivityPlaceholderView.swift
//  hangulblitz
//

import SwiftUI

struct ActivityPlaceholderView: View {
    let title: String
    var showsCloseButton = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Color(.systemBackground)
            .ignoresSafeArea()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if showsCloseButton {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                        }
                    }
                }
            }
    }
}
