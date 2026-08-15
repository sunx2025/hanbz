//
//  PracticeScoreBar.swift
//  hangulblitz
//

import SwiftUI

struct PracticeScoreBar: View {
    let score: Double

    private let ringSize: CGFloat = 20
    private let horizontalInset: CGFloat = 6

    private var clampedScore: Double {
        min(max(score, 0), 6)
    }

    private var isBlitz: Bool {
        clampedScore >= ProgressPolicy.blitzThreshold
    }

    var body: some View {
        GeometryReader { geometry in
            let travel = max(
                0,
                geometry.size.width - horizontalInset * 2 - ringSize
            )
            let ringX = horizontalInset + travel * clampedScore / 6

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.accentColor.opacity(0.06),
                                Color.accentColor.opacity(0.55),
                                Color.accentColor
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.clear, .black.opacity(0.28)],
                                    startPoint: .center,
                                    endPoint: .trailing
                                )
                            )
                    }

                Circle()
                    .fill(Color.accentColor)
                    .strokeBorder(.white, lineWidth: 2)
                    .frame(width: ringSize, height: ringSize)
                    .offset(x: ringX)

                Image(systemName: "bolt.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(isBlitz ? 1 : 0.6))
                    .frame(width: ringSize, height: ringSize)
                    .padding(.trailing, horizontalInset)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .frame(height: 32)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            Text(
                "reading.completion.score.accessibility_label",
                comment: "Accessibility label for the score position shown on the reading practice completion bar."
            )
        )
        .accessibilityValue(Text(verbatim: clampedScore.formatted(.number.precision(.fractionLength(1)))))
    }
}

#Preview("Practice score bar") {
    VStack(spacing: 24) {
        ForEach([0.0, 1, 2.7, 5, 5.5, 6], id: \.self) { score in
            PracticeScoreBar(score: score)
        }
    }
    .padding()
}
