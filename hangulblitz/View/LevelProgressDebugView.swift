//
//  LevelProgressDebugView.swift
//  hangulblitz
//

import SwiftUI

#if DEBUG
struct LevelProgressDebugView: View {
    let level: Level
    let progress: UserProgress

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var mode: Mode = .reading

    private enum Mode: String, CaseIterable, Identifiable {
        case reading
        case listening

        var id: Self { self }

        func matches(_ kind: ActivityKind) -> Bool {
            switch (self, kind) {
            case (.reading, .reading), (.listening, .listening):
                true
            default:
                false
            }
        }
    }

    private var levelState: LevelLearningState {
        progress.levels[level.id] ?? LevelLearningState()
    }

    private var levelProgress: LevelProgress {
        LevelProgress(level: level, state: levelState)
    }

    var body: some View {
        GeometryReader { geometry in
            let width = contentWidth(in: geometry.size.width)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    levelSummary

                    Picker("Practice mode", selection: $mode) {
                        ForEach(Mode.allCases) { mode in
                            Text(modeTitle(mode, availableWidth: width))
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    activityAverages
                    itemTable
                }
                .frame(width: width)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
            }
            .background(Color(.systemGroupedBackground))
        }
        .navigationTitle("Progress Debug")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var levelSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Level total")
                    .font(.headline)

                Spacer()

                if levelProgress.isBlitz {
                    Label("Blitz", systemImage: "bolt.fill")
                        .foregroundStyle(.tint)
                } else if let value = levelProgress.standardProgress {
                    Text(value, format: .percent.precision(.fractionLength(0)))
                        .monospacedDigit()
                } else {
                    Text("—")
                        .foregroundStyle(.secondary)
                }
            }

            ProgressView(value: levelProgress.standardProgress ?? 0)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 16))
    }

    private var activityAverages: some View {
        HStack(spacing: 12) {
            averageCard(title: "Current Avg", scope: .current)
            averageCard(title: "Mixed Avg", scope: .mixed)
        }
    }

    private func averageCard(title: String, scope: PracticeScope) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let score = activityScore(scope: scope) {
                Text(score, format: .number.precision(.fractionLength(1)))
                    .font(.title2.bold())
                    .monospacedDigit()
            } else {
                Text("—")
                    .font(.title2.bold())
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 16))
    }

    private var itemTable: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("Item")
                    .frame(width: 44, alignment: .leading)
                Text("Avg")
                    .frame(width: 44, alignment: .trailing)
                Text("Attempts (oldest → newest)")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            if displayedItems.isEmpty {
                Text("No items configured")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            } else {
                ForEach(Array(displayedItems.enumerated()), id: \.element) { index, item in
                    itemRow(item)

                    if index < displayedItems.count - 1 {
                        Divider()
                            .padding(.leading, 12)
                    }
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 16))
    }

    private func itemRow(_ item: String) -> some View {
        let itemProgress = levelState.items[LevelItemID(levelID: level.id, text: item)]
        let mastery = itemMastery(itemProgress)
        let attempts = attemptTokens(itemProgress)

        return HStack(spacing: 12) {
            Text(item)
                .font(.headline)
                .frame(width: 44, alignment: .leading)

            Group {
                if let mastery {
                    Text(mastery, format: .number.precision(.fractionLength(1)))
                        .monospacedDigit()
                } else {
                    Text("—")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 44, alignment: .trailing)

            if attempts.isEmpty {
                Text("—")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(attempts.enumerated()), id: \.offset) { _, attempt in
                            AttemptChip(attempt: attempt)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(minHeight: 48)
    }

    private var displayedItems: [String] {
        var seen = Set<String>()

        return [activity(scope: .current), activity(scope: .mixed)]
            .compactMap { $0 }
            .flatMap(\.items)
            .map(PracticeAudioCatalog.normalizedText)
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    private func activity(scope: PracticeScope) -> LearningActivity? {
        level.allActivities.first { activity in
            activity.scope == scope && mode.matches(activity.kind)
        }
    }

    private func activityScore(scope: PracticeScope) -> Double? {
        guard let activity = activity(scope: scope) else { return nil }

        let activityProgress = ActivityProgress(
            activity: activity,
            levelID: level.id,
            state: levelState
        )
        return activityProgress.hasAttempt ? activityProgress.mastery : nil
    }

    private func itemMastery(_ progress: LevelItemProgress?) -> Double? {
        switch mode {
        case .reading:
            progress?.reading.mastery
        case .listening:
            progress?.listening.mastery
        }
    }

    private func attemptTokens(_ progress: LevelItemProgress?) -> [AttemptToken] {
        switch mode {
        case .reading:
            return progress?.reading.attempts.map { attempt in
                let result: AttemptToken.Result
                switch attempt.outcome {
                case .correct:
                    result = .correct(time: attempt.recallTime)
                case .incorrect:
                    result = .incorrect
                case .timedOut:
                    result = .timedOut
                }

                return AttemptToken(
                    scope: attempt.scope,
                    result: result
                )
            } ?? []

        case .listening:
            return progress?.listening.attempts.map { attempt in
                let result: AttemptToken.Result
                switch attempt.outcome {
                case .correct:
                    result = .correct(time: attempt.responseTime)
                case .incorrect:
                    result = .incorrect
                case .notSure:
                    result = .notSure
                case .timedOut:
                    result = .timedOut
                }

                return AttemptToken(
                    scope: attempt.scope,
                    result: result
                )
            } ?? []
        }
    }

    private func modeTitle(_ mode: Mode, availableWidth: CGFloat) -> String {
        if availableWidth >= 300 {
            return mode == .reading ? "Reading" : "Listening"
        }
        return mode == .reading ? "R" : "L"
    }

    private func contentWidth(in availableWidth: CGFloat) -> CGFloat {
        if horizontalSizeClass == .regular {
            return availableWidth * 8 / 12
        }
        return max(availableWidth - 48, 0)
    }
}

private struct AttemptToken {
    let scope: PracticeScope
    let result: Result

    enum Result {
        case correct(time: TimeInterval)
        case incorrect
        case timedOut
        case notSure
    }
}

private struct AttemptChip: View {
    let attempt: AttemptToken

    var body: some View {
        HStack(spacing: 4) {
            Text(attempt.scope == .current ? "C" : "M")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)

            Image(systemName: symbolName)
                .foregroundStyle(symbolColor)

            if case let .correct(time) = attempt.result {
                Text(time, format: .number.precision(.fractionLength(1)))
                    .monospacedDigit()
                Text("s")
                    .foregroundStyle(.secondary)
                    .padding(.leading, -4)
            }
        }
        .font(.caption)
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(.capsule)
    }

    private var symbolName: String {
        switch attempt.result {
        case .correct:
            "checkmark.circle.fill"
        case .incorrect:
            "xmark.circle.fill"
        case .timedOut:
            "clock.fill"
        case .notSure:
            "questionmark.circle.fill"
        }
    }

    private var symbolColor: Color {
        switch attempt.result {
        case .correct:
            .green
        case .incorrect:
            .red
        case .timedOut:
            .orange
        case .notSure:
            .yellow
        }
    }
}
#endif
