//
//  CircularCountdownIndicator.swift
//  hangulblitz
//

import SwiftUI

/// A visual countdown only. The practice session remains the source of truth
/// for timing and scoring.
struct CircularCountdownIndicator: View {
    let remainingFraction: Double
    var duration: TimeInterval = ProgressPolicy.listeningTimeout

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(.systemGray5))

            CountdownPie(fraction: clampedFraction)
                .fill(Color.accentColor)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            Text(
                "listening.timer.accessibility_label",
                comment: "Accessibility label for the circular listening-answer countdown."
            )
        )
        .accessibilityValue(Text(verbatim: remainingSeconds.formatted()))
    }

    private var clampedFraction: Double {
        min(max(remainingFraction, 0), 1)
    }

    private var remainingSeconds: Int {
        Int(ceil(clampedFraction * duration))
    }
}

private struct CountdownPie: Shape {
    let fraction: Double

    func path(in rect: CGRect) -> Path {
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        path.move(to: centre)
        path.addArc(
            center: centre,
            radius: radius,
            startAngle: .degrees(-90),
            endAngle: .degrees(-90 + 360 * min(max(fraction, 0), 1)),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

#Preview {
    CircularCountdownIndicator(remainingFraction: 0.7)
        .frame(width: 40, height: 40)
        .padding()
}
