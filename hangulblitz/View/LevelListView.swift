//
//  LevelListView.swift
//  hangulblitz
//

import SwiftUI

struct LevelListView: View {
    let levels: [Level]
    let progress: UserProgress
    @Binding var selectedLevelID: String?
    let usesCardRows: Bool

    var body: some View {
        List(levels, selection: $selectedLevelID) { level in
            NavigationLink(value: level.id) {
                LevelRow(
                    level: level,
                    progress: displayProgress(for: level),
                    isSelected: !usesCardRows && level.id == selectedLevelID,
                    presentation: usesCardRows ? .card : .sidebar
                )
            }
//            .listRowInsets(
//                usesCardRows
//                    ? EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
//                    : EdgeInsets()
//            )
            .listRowInsets(
                EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
            )

            .listRowSeparator(usesCardRows ? .hidden : .visible)
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(
            usesCardRows
                ? Color(.systemGroupedBackground)
                : Color(.secondarySystemGroupedBackground)
        )
        .navigationBarTitleDisplayMode(.inline)
        .navigationLinkIndicatorVisibility(.hidden)
    }

    private func displayProgress(for level: Level) -> LevelDisplayProgress? {
        let levelProgress = LevelProgress(
            level: level,
            state: progress.levels[level.id] ?? LevelLearningState()
        )

        guard let standardProgress = levelProgress.standardProgress else {
            return nil
        }

        return LevelDisplayProgress(
            standardProgress: standardProgress,
            isBlitz: levelProgress.isBlitz
        )
    }
}

#Preview("Level list – Progress states") {
    @Previewable @State var selectedLevelID: String? = "level-1"
    @Previewable @State var preferredCompactColumn = NavigationSplitViewColumn.sidebar

    NavigationSplitView(preferredCompactColumn: $preferredCompactColumn) {
        LevelListView(
            levels: .previewLevels,
            progress: .previewLevelProgress,
            selectedLevelID: $selectedLevelID,
            usesCardRows: true
            //usesCardRows: false
        )
    } detail: {
        if let selectedLevelID,
           let level = Array.previewLevels.first(where: { $0.id == selectedLevelID }) {
            Text(verbatim: level.title)
        } else {
            EmptyView()
        }
    }
    .environment(\.locale, Locale(identifier: "en_AU"))
}

private extension UserProgress {
    static var previewLevelProgress: UserProgress {
        var progress = UserProgress()
        let sessionID = UUID()

        progress.record(
            ReadingAttempt(
                sessionID: sessionID,
                scope: .current,
                outcome: .correct,
                recallTime: 5.5,
                timeoutThreshold: ProgressPolicy.readingTimeout,
                recordedAt: .now
            ),
            levelID: "level-1",
            text: "아"
        )
        progress.record(
            ListeningAttempt(
                sessionID: sessionID,
                scope: .current,
                outcome: .correct,
                responseTime: 5.5,
                timeoutThreshold: ProgressPolicy.listeningTimeout,
                recordedAt: .now
            ),
            levelID: "level-1",
            text: "아"
        )
        progress.record(
            ListeningAttempt(
                sessionID: sessionID,
                scope: .current,
                outcome: .incorrect,
                responseTime: 3,
                timeoutThreshold: ProgressPolicy.listeningTimeout,
                recordedAt: .now
            ),
            levelID: "level-1",
            text: "아"
        )

        progress.record(
            ReadingAttempt(
                sessionID: sessionID,
                scope: .current,
                outcome: .correct,
                recallTime: 0.5,
                timeoutThreshold: ProgressPolicy.readingTimeout,
                recordedAt: .now
            ),
            levelID: "level-2",
            text: "아"
        )
        progress.record(
            ListeningAttempt(
                sessionID: sessionID,
                scope: .current,
                outcome: .correct,
                responseTime: 0.5,
                timeoutThreshold: ProgressPolicy.listeningTimeout,
                recordedAt: .now
            ),
            levelID: "level-2",
            text: "아"
        )

        return progress
    }
}

private extension Array where Element == Level {
    static var previewLevels: [Level] {
        [
            Level.preview(
                id: "level-1",
                number: 1,
                title: "Basic Vowels",
                description: "ㅏ ㅓ ㅗ ㅜ ㅡ ㅣ and silent initial ㅇ",
                includesActivities: true
            ),
            Level.preview(
                id: "level-2",
                number: 2,
                title: "Basic Consonants ㄱ ㄴ",
                description: "ㄱ ㄴ and combinations",
                includesActivities: true
            ),
            Level.preview(
                id: "level-preview-3",
                number: 3,
                title: "Basic Consonants ㄷ ㄹ",
                description: "ㄷ ㄹ and combinations"
            ),
            Level.preview(
                id: "level-preview-4",
                number: 4,
                title: "Basic Consonants ㅁ ㅂ",
                description: "ㅁ ㅂ and combinations"
            ),
            Level.preview(
                id: "level-preview-5",
                number: 5,
                title: "Mixed Practice I",
                description: "가 거 고 구 그 기 etc."
            )
        ]
    }
}

private extension Level {
    static func preview(
        id: String,
        number: Int,
        title: String,
        description: String,
        includesActivities: Bool = false
    ) -> Level {
        let reading = LearningActivity(
            id: "\(id)-reading",
            kind: .reading,
            scope: .current,
            title: "Reading Practice",
            description: "",
            itemSections: includesActivities ? [["아"]] : [],
            contrasts: []
        )
        let listening = LearningActivity(
            id: "\(id)-listening",
            kind: .listening,
            scope: .current,
            title: "Listening Practice",
            description: "",
            itemSections: includesActivities ? [["아"]] : [],
            contrasts: []
        )

        return Level(
            id: id,
            number: number,
            title: title,
            description: description,
            overview: nil,
            currentActivities: includesActivities ? [reading, listening] : [],
            mixedActivities: []
        )
    }
}
