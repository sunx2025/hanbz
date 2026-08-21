//
//  LevelProgressIndicator.swift
//  hangulblitz
//

import SwiftUI

/// Compact level progress used by both phone cards and the tablet sidebar.
/// Blitz is a separate achievement state, so both 100% and Blitz use a full track.
struct LevelProgressIndicator: View {
    let progress: Double
    let isBlitz: Bool

    private let trackWidth: CGFloat = 96
    private let trackHeight: CGFloat = 8

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    private var percentage: Int {
        clampedProgress >= 1 ? 100 : Int(clampedProgress * 100)
    }

    var body: some View {
        HStack(spacing: 4) {
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color("Muted"))

                Capsule()
                    .fill(.tint)
                    .frame(width: trackWidth * clampedProgress)
            }
            .frame(width: trackWidth, height: trackHeight)

            if isBlitz {
                Label {
                    Text(
                        "level.progress.blitz",
                        comment: "Exceptional level mastery shown after every scored activity reaches Blitz status."
                    )
                } icon: {
                    Image(systemName: "bolt.fill")
                }
                .labelStyle(.titleAndIcon)
            } else {
                Text(
                    Double(percentage) / 100,
                    format: .percent.precision(.fractionLength(0))
                )
            }
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(.tint)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            Text(
                "level.progress.accessibility_label",
                comment: "Accessibility label for the mastery progress of a level."
            )
        )
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: Text {
        if isBlitz {
            Text(
                "level.progress.blitz",
                comment: "Exceptional level mastery shown after every scored activity reaches Blitz status."
            )
        } else {
            Text(
                Double(percentage) / 100,
                format: .percent.precision(.fractionLength(0))
            )
        }
    }
}

#Preview("Level progress") {
    VStack(alignment: .leading, spacing: 16) {
        LevelProgressIndicator(progress: 0.15, isBlitz: false)
        LevelProgressIndicator(progress: 0.51, isBlitz: false)
        LevelProgressIndicator(progress: 1, isBlitz: false)
        LevelProgressIndicator(progress: 1, isBlitz: true)
    }
    .padding()
}
