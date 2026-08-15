//
//  AudioPlaybackIndicator.swift
//  hangulblitz
//

import SwiftUI

struct AudioPlaybackIndicator: View {
    let isPlaying: Bool
    var isLoading = false
    let samples: [CGFloat]
    let romanization: String
    let replay: () -> Void

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .frame(height: 40)
                    .transition(.opacity)
            } else if isPlaying {
                VStack(spacing: 8) {
                    AudioWaveform(samples: samples)
                        .frame(height: 40)

                    Text(verbatim: romanization)
                        .font(.title2)
                        .foregroundStyle(.primary)
                }
                .transition(.opacity)
            } else {
                Button(action: replay) {
                    Image(systemName: "speaker.wave.2.fill")
                }
                .buttonStyle(AudioReplayButtonStyle())
                .accessibilityLabel(
                    Text("practice.audio.replay", comment: "Accessibility label for replaying the current practice audio.")
                )
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .animation(.easeInOut(duration: 0.18), value: isPlaying)
        .animation(.easeInOut(duration: 0.18), value: isLoading)
    }
}

private struct AudioReplayButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 40, height: 40)
            .foregroundStyle(Color.accentColor)
            .background(Color.muted, in: .circle)
            .overlay {
                Circle()
                    .strokeBorder(Color.accentColor, lineWidth: 1)
            }
            .contentShape(.circle)
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

private struct AudioWaveform: View {
    let samples: [CGFloat]

    var body: some View {
        Canvas { context, size in
            let midpoint = size.height / 2
//            var baseline = Path()
//            baseline.move(to: CGPoint(x: 0, y: midpoint))
//            baseline.addLine(to: CGPoint(x: size.width, y: midpoint))
//            context.stroke(
//                baseline,
//                with: .color(.accentColor.opacity(0.8)),
//                style: StrokeStyle(lineWidth: 1, dash: [4, 5])
//            )

            guard !samples.isEmpty else { return }
            let spacing = size.width / CGFloat(samples.count)

            for (index, sample) in samples.enumerated() {
                let height = max(3, sample * size.height * 0.88)
                let x = (CGFloat(index) + 0.5) * spacing
                var bar = Path()
                bar.move(to: CGPoint(x: x, y: midpoint - height / 2))
                bar.addLine(to: CGPoint(x: x, y: midpoint + height / 2))
                context.stroke(bar, with: .color(.accentColor), lineWidth: 1.25)
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview("Audio playback indicator") {
    VStack(spacing: 40) {
        AudioPlaybackIndicator(
            isPlaying: true,
            samples: (0..<40).map { CGFloat((sin(Double($0) * 0.55) + 1.2) / 2.2) },
            romanization: "a",
            replay: {}
        )

        AudioPlaybackIndicator(
            isPlaying: false,
            samples: [],
            romanization: "a",
            replay: {}
        )
    }
    .padding()
}
