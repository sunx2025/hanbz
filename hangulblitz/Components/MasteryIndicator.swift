//
//  MasteryIndicator.swift
//  hangulblitz
//

import SwiftUI

struct MasteryIndicator: View {
    enum Shape {
        case star
        case circle
    }

    let value: Double
    var maximum = 5
    var shape: Shape = .circle
    var showsBlitz = false

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<maximum, id: \.self) { index in
                Image(systemName: symbol(for: index))
            }

            if showsBlitz {
                Image(systemName: "bolt.fill")
            }
        }
        .font(.footnote)
        .foregroundStyle(.tint)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    private func symbol(for index: Int) -> String {
        let remainingValue = value - Double(index)
        let isFull = remainingValue >= 1
        let isHalf = remainingValue >= 0.5

        switch shape {
        case .star:
            if isFull { return "star.fill" }
            if isHalf { return "star.leadinghalf.filled" }
            return "star"
        case .circle:
            if isFull { return "circle.fill" }
            if isHalf { return "circle.lefthalf.filled" }
            return "circle"
        }
    }

    private var accessibilityDescription: Text {
        Text(
            "progress.accessibility_label \(value) \(maximum)",
            comment: "Accessibility description for a progress indicator. The first value is progress and the second is the maximum."
        )
    }
}
