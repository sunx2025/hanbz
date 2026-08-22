//
//  OverviewView.swift
//  hangulblitz
//

import SwiftUI

struct OverviewView: View {
    let level: Level

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.locale) private var locale
    @State private var audioPlayer = PracticeAudioPlayer()

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                if let overview = level.overview {
                    OverviewArticle(
                        overview: overview,
                        usesCJKHeadingStyle: usesCJKHeadingStyle,
                        onPlayAudio: { text in
                            audioPlayer.play(text: text)
                        }
                    )
                    .frame(width: articleWidth(in: geometry.size.width))
                    .padding(.vertical, 32)
                    .frame(maxWidth: .infinity)
                }
            }
            .background(Color(.systemBackground))
        }
        .navigationTitle(level.title)
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .top) {
            if let issue = audioPlayer.audioIssue {
                PracticeAudioIssueBanner(issue: issue)
                    .frame(maxWidth: 480)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: issue.id) {
                        try? await Task.sleep(for: .seconds(4))
                        audioPlayer.dismissIssue(id: issue.id)
                    }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: audioPlayer.audioIssue?.id)
        .onDisappear {
            audioPlayer.stop()
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

private struct OverviewArticle: View {
    let overview: Overview
    let usesCJKHeadingStyle: Bool
    let onPlayAudio: (String) -> Void

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 32) {
            ForEach(Array(overview.sections.enumerated()), id: \.offset) { _, section in
                OverviewSectionView(
                    section: section,
                    usesCJKHeadingStyle: usesCJKHeadingStyle,
                    onPlayAudio: onPlayAudio
                )
            }

            BrandLogo(width: 104)
                .padding(.top, 8)
        }
    }
}

private struct OverviewSectionView: View {
    let section: OverviewSection
    let usesCJKHeadingStyle: Bool
    let onPlayAudio: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(section.title)
                .font(usesCJKHeadingStyle ? .headline.bold() : .title3.bold())
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(section.blocks.enumerated()), id: \.offset) { _, block in
                    switch block {
                    case let .paragraph(text):
                        Text(text)
                            .font(.callout)
                            .frame(maxWidth: .infinity, alignment: .leading)

                    case let .note(text):
                        Text(text)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                    case let .table(table):
                        OverviewTableView(table: table, onPlayAudio: onPlayAudio)
                    }
                }
            }
        }
    }
}

private struct OverviewTableView: View {
    let table: OverviewTable
    let onPlayAudio: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(table.rows.enumerated()), id: \.offset) { index, row in
                OverviewTableRowView(row: row, onPlayAudio: onPlayAudio)

                if index < table.rows.count - 1 {
                    Divider()
                }
            }
        }
        .padding(.horizontal, 16)
        .background(Color("Group Background"))
        .clipShape(.rect(cornerRadius: 20))
    }
}

private struct OverviewTableRowView: View {
    let row: OverviewTableRow
    let onPlayAudio: (String) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(row.hangul)
                .font(.headline.bold())
                .lineLimit(1)
                .frame(minWidth: 56, alignment: .leading)

            Text(row.note)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)

            Button {
                onPlayAudio(row.hangul)
            } label: {
                Image(systemName: "speaker.wave.2.fill")
                    .imageScale(.small)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.circle)
            .controlSize(.small)
            //.frame(width: 44, height: 44)
            .disabled(row.audio == .unavailable)
            .accessibilityLabel(accessibilityLabel)
        }
        .padding(8)
        .frame(minHeight: 44)
    }

    private var accessibilityLabel: Text {
        let format = String(
            localized: "overview.audio.play",
            defaultValue: "Play pronunciation for %@",
            comment: "Accessibility label for a button that plays the pronunciation of a Korean item. The placeholder is the Korean text."
        )
        return Text(String(format: format, row.hangul))
    }
}

#Preview("Overview – iPhone") {
    let locale = Locale(identifier: "en_AU")
    let level = MockCourse.course(locale: locale).levels[0]

    NavigationStack {
        OverviewView(level: level)
    }
    .environment(\.locale, locale)
}

#Preview("Overview – iPad landscape") {
    let locale = Locale(identifier: "zh_Hans")
    let level = MockCourse.course(locale: locale).levels[0]

    NavigationStack {
        OverviewView(level: level)
    }
    .environment(\.locale, locale)
    .environment(\.horizontalSizeClass, .regular)
    .frame(width: 1_194, height: 834)
}
