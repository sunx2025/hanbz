//
//  ApplyView.swift
//  hangulblitz
//

import SwiftUI

struct ApplyView: View {
    let level: Level

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.locale) private var locale
    @State private var speechPlayer = KoreanSpeechPlayer()

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                if let apply = level.apply {
                    CourseArticleView(
                        article: apply,
                        usesCJKHeadingStyle: usesCJKHeadingStyle,
                        tableLayout: .stacked,
                        onPlayAudio: speechPlayer.play
                    )
                    .frame(width: articleWidth(in: geometry.size.width))
                    .padding(.vertical, 32)
                    .frame(maxWidth: .infinity)
                }
            }
            .background(Color(.systemBackground))
        }
        .navigationTitle(
            Text(
                "activity.apply.title",
                comment: "Title of the optional words and phrases article."
            )
        )
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .top) {
            if let issue = speechPlayer.issue {
                AudioIssueBanner(
                    message: String(
                        localized: "apply.audio.issue.missing_korean_voice",
                        comment: "Toast shown when the device has no Korean text-to-speech voice installed."
                    )
                )
                .frame(maxWidth: 480)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .task(id: issue.id) {
                    try? await Task.sleep(for: .seconds(4))
                    speechPlayer.dismissIssue(id: issue.id)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: speechPlayer.issue?.id)
        .onDisappear {
            speechPlayer.stop()
        }
    }

    private func articleWidth(in availableWidth: CGFloat) -> CGFloat {
        if horizontalSizeClass == .regular {
            return availableWidth * 8 / 12
        }
        return max(availableWidth - 48, 0)
    }

    private var usesCJKHeadingStyle: Bool {
        switch locale.language.languageCode?.identifier {
        case "zh", "ja", "ko":
            true
        default:
            false
        }
    }
}

#Preview("Apply – iPhone") {
    let locale = Locale(identifier: "en_AU")
    let level = MockCourse.course(locale: locale).levels[2]

    NavigationStack {
        ApplyView(level: level)
    }
    .environment(\.locale, locale)
}
