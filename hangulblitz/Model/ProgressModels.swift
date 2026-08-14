//
//  ProgressModels.swift
//  hangulblitz
//

import Foundation

enum ProgressPolicy {
    static let maximumAttemptHistory = 5
}

struct User: Identifiable {
    let id: String
    var name: String
    var progress: UserProgress
}

struct UserProgress {
    var levels: [String: LevelLearningState] = [:]

    mutating func record(
        _ attempt: ReadingAttempt,
        levelID: String,
        text: String
    ) {
        let itemID = LevelItemID(levelID: levelID, text: text)
        levels[levelID, default: LevelLearningState()]
            .items[itemID, default: LevelItemProgress()]
            .reading
            .record(attempt)
    }

    mutating func record(
        _ attempt: ListeningAttempt,
        levelID: String,
        text: String
    ) {
        let itemID = LevelItemID(levelID: levelID, text: text)
        levels[levelID, default: LevelLearningState()]
            .items[itemID, default: LevelItemProgress()]
            .listening
            .record(attempt)
    }

    mutating func markNonScoredActivityCompleted(
        levelID: String,
        activityID: String
    ) {
        levels[levelID, default: LevelLearningState()]
            .completedNonScoredActivityIDs
            .insert(activityID)
    }

    static func load() -> UserProgress {
        // TODO: Load persisted user progress when storage is introduced.
        UserProgress()
    }

    func save() {
        // TODO: Persist user progress when storage is introduced.
    }
}

struct LevelItemID: Hashable {
    let levelID: String
    let text: String

    init(levelID: String, text: String) {
        self.levelID = levelID
        self.text = text.precomposedStringWithCanonicalMapping
    }
}

struct LevelLearningState {
    var items: [LevelItemID: LevelItemProgress] = [:]
    var completedNonScoredActivityIDs: Set<String> = []
}

struct LevelItemProgress {
    var reading = ReadingItemProgress()
    var listening = ListeningItemProgress()
}

struct ReadingItemProgress {
    var mastery: Double?
    var attempts: [ReadingAttempt] = []

    mutating func record(_ attempt: ReadingAttempt) {
        attempts.append(attempt)
        attempts.keepMostRecent(ProgressPolicy.maximumAttemptHistory)
    }
}

struct ListeningItemProgress {
    var mastery: Double?
    var attempts: [ListeningAttempt] = []

    mutating func record(_ attempt: ListeningAttempt) {
        attempts.append(attempt)
        attempts.keepMostRecent(ProgressPolicy.maximumAttemptHistory)
    }
}

struct ReadingAttempt {
    let sessionID: UUID
    let scope: PracticeScope
    let outcome: ReadingAttemptOutcome
    let recallTime: TimeInterval
    let timeoutThreshold: TimeInterval
    let recordedAt: Date
}

enum ReadingAttemptOutcome {
    case correct
    case incorrect
    case timedOut
}

struct ListeningAttempt {
    let sessionID: UUID
    let scope: PracticeScope
    let outcome: ListeningAttemptOutcome
    let responseTime: TimeInterval
    let timeoutThreshold: TimeInterval
    let recordedAt: Date
}

enum ListeningAttemptOutcome {
    case correct
    case incorrect
    case notSure
    case timedOut
}

// Activity progress is a snapshot derived from the activity's configured items.
struct ActivityProgress {
    let mastery: Double?
    let coverage: Double
    let scopeEvidenceCoverage: Double
    let practisedItemCount: Int
    let totalItemCount: Int
    let hasAttempt: Bool
    let isCompleted: Bool

    init(
        activity: LearningActivity,
        levelID: String,
        state: LevelLearningState
    ) {
        let itemIDs = Set(
            activity.items.map { LevelItemID(levelID: levelID, text: $0) }
        )

        totalItemCount = itemIDs.count

        if activity.kind == .guided {
            let completed = state.completedNonScoredActivityIDs.contains(activity.id)
            mastery = nil
            coverage = completed ? 1 : 0
            scopeEvidenceCoverage = coverage
            practisedItemCount = 0
            hasAttempt = completed
            isCompleted = completed
            return
        }

        let itemProgresses = itemIDs.map { state.items[$0] }
        let masteryValues: [Double]
        let practisedItems: [Bool]
        let scopeEvidenceItems: [Bool]

        switch activity.kind {
        case .reading:
            masteryValues = itemProgresses.compactMap { $0?.reading.mastery }
            practisedItems = itemProgresses.map { progress in
                !(progress?.reading.attempts.isEmpty ?? true)
            }
            scopeEvidenceItems = itemProgresses.map { progress in
                progress?.reading.attempts.contains { $0.scope == activity.scope } ?? false
            }

        case .listening:
            masteryValues = itemProgresses.compactMap { $0?.listening.mastery }
            practisedItems = itemProgresses.map { progress in
                !(progress?.listening.attempts.isEmpty ?? true)
            }
            scopeEvidenceItems = itemProgresses.map { progress in
                progress?.listening.attempts.contains { $0.scope == activity.scope } ?? false
            }

        case .guided:
            masteryValues = []
            practisedItems = []
            scopeEvidenceItems = []
        }

        mastery = masteryValues.average
        practisedItemCount = practisedItems.count(where: { $0 })
        coverage = Self.ratio(practisedItemCount, to: totalItemCount)
        scopeEvidenceCoverage = Self.ratio(
            scopeEvidenceItems.count(where: { $0 }),
            to: totalItemCount
        )
        hasAttempt = scopeEvidenceItems.contains(true)
        isCompleted = totalItemCount > 0 && scopeEvidenceCoverage == 1
    }

    private static func ratio(_ numerator: Int, to denominator: Int) -> Double {
        guard denominator > 0 else { return 0 }
        return Double(numerator) / Double(denominator)
    }
}

// Level progress is a snapshot derived from its scored activities.
struct LevelProgress {
    let mastery: Double?
    let coverage: Double
    let activityProgresses: [String: ActivityProgress]

    init(level: Level, state: LevelLearningState) {
        let progresses = level.allActivities
            .filter(\.kind.isScored)
            .map { activity in
                (
                    activity.id,
                    ActivityProgress(
                        activity: activity,
                        levelID: level.id,
                        state: state
                    )
                )
            }

        activityProgresses = Dictionary(uniqueKeysWithValues: progresses)
        mastery = activityProgresses.values.compactMap(\.mastery).average
        coverage = Array(activityProgresses.values.map(\.coverage)).average ?? 0
    }
}

private extension Collection where Element == Double {
    var average: Double? {
        guard !isEmpty else { return nil }
        return reduce(0, +) / Double(count)
    }
}

private extension Array {
    mutating func keepMostRecent(_ maximumCount: Int) {
        guard count > maximumCount else { return }
        removeFirst(count - maximumCount)
    }
}
