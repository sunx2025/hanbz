//
//  PracticeProgressBar.swift
//  hangulblitz
//

import SwiftUI

struct PracticeProgressBar: View {
    let value: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(.quaternarySystemFill))

                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: geometry.size.width * min(max(value, 0), 1))
            }
        }
        .frame(height: 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            Text("practice.progress.accessibility_label", comment: "Accessibility label for practice progress.")
        )
        .accessibilityValue(
            Text(verbatim: value.formatted(.percent.precision(.fractionLength(0))))
        )
    }
}

#Preview("Practice progress") {
    PracticeProgressBar(value: 0.35)
        .padding()
}
