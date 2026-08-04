//
//  PracticeSessionShell.swift
//  hangulblitz
//

import SwiftUI

struct PracticeSessionShell<Content: View>: View {
    let title: String
    let background: Color
    let close: () -> Void
    private let content: Content

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    init(
        title: String,
        background: Color = Color(.systemGroupedBackground),
        close: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.background = background
        self.close = close
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(background.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .toolbar {
                if horizontalSizeClass == .regular {
                    ToolbarItem(placement: .topBarLeading) {
                        BrandLogo()
                            .allowsHitTesting(false)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: close) {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(
                        Text("practice.close", comment: "Accessibility label for closing a practice session.")
                    )
                }
            }
    }
}


enum PracticeLayout {
    static let flashCardMaxWidth: CGFloat = 440
    static let flashCardHeightToWidthRatio: CGFloat = 1.4

    static let flashCardMaxHeight =
        flashCardMaxWidth * flashCardHeightToWidthRatio

    // SwiftUI expresses aspect ratios as width divided by height.
    static let flashCardAspectRatio =
        1 / flashCardHeightToWidthRatio
}

