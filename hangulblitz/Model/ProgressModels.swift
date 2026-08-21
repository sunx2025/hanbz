//
//  ProgressModels.swift
//  hangulblitz
//

import Foundation

enum ProgressPolicy {
    nonisolated static let maximumAttemptHistory = 5
    // Five points fills the normal mastery UI. Scores above this remain useful
    // for distinguishing exceptionally fast recall, but cannot add more than
    // 100% to an activity's contribution to its level.
    nonisolated static let masteryFullScore = 5.0
    nonisolated static let readingTimeout: TimeInterval = 6
    nonisolated static let listeningTimeout: TimeInterval = 6
    nonisolated static let listeningMinimumAnswerProgress = 0.5
    nonisolated static let listeningCorrectFeedbackDuration: TimeInterval = 0.8
    nonisolated static let listeningOtherFeedbackDuration: TimeInterval = 1
    nonisolated static let blitzThreshold = 5.5
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
        mastery = attempts.map(\.score).average
    }
}

struct ListeningItemProgress {
    var mastery: Double?
    var attempts: [ListeningAttempt] = []

    mutating func record(_ attempt: ListeningAttempt) {
        attempts.append(attempt)
        attempts.keepMostRecent(ProgressPolicy.maximumAttemptHistory)
        mastery = attempts.map(\.score).average
    }
}

struct ReadingAttempt {
    let sessionID: UUID
    let scope: PracticeScope
    let outcome: ReadingAttemptOutcome
    let recallTime: TimeInterval
    let timeoutThreshold: TimeInterval
    let recordedAt: Date

    var score: Double {
        guard outcome == .correct else { return 0 }

        switch recallTime {
        case ..<1:
            return 6
        case ..<2:
            return 5
        case ..<3:
            return 4
        case ..<4:
            return 3
        case ..<5:
            return 2
        case ..<timeoutThreshold:
            return 1
        default:
            return 0
        }
    }
}

enum ReadingAttemptOutcome: Equatable {
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

    var score: Double {
        guard outcome == .correct else { return 0 }

        switch responseTime {
        case ..<1:
            return 6
        case ..<2:
            return 5
        case ..<3:
            return 4
        case ..<4:
            return 3
        case ..<5:
            return 2
        case ..<timeoutThreshold:
            return 1
        default:
            return 0
        }
    }
}

enum ListeningAttemptOutcome: Equatable {
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
            activity.items
                .map(PracticeAudioCatalog.normalizedText)
                .filter { !$0.isEmpty }
                .map { LevelItemID(levelID: levelID, text: $0) }
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
            masteryValues = itemProgresses.map { $0?.reading.mastery ?? 0 }
            practisedItems = itemProgresses.map { progress in
                !(progress?.reading.attempts.isEmpty ?? true)
            }
            scopeEvidenceItems = itemProgresses.map { progress in
                progress?.reading.attempts.contains { $0.scope == activity.scope } ?? false
            }

        case .listening:
            masteryValues = itemProgresses.map { $0?.listening.mastery ?? 0 }
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

        practisedItemCount = practisedItems.count(where: { $0 })
        // Once an activity has evidence, every configured item contributes to
        // mastery. Unpractised items count as zero so a partial session cannot
        // make the whole activity appear mastered. With no evidence at all the
        // optional remains nil, allowing the UI to hide an untouched activity.
        mastery = practisedItemCount > 0 ? masteryValues.average : nil
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
    // Normal progress and Blitz deliberately express different achievements.
    // Each activity first caps at 100% (score 5) before the level average is
    // calculated. Its score above 5 therefore cannot compensate for another
    // activity below 5. Level Blitz is awarded separately only when every
    // valid scored activity has itself reached the Blitz threshold.
    let standardProgress: Double?
    let isBlitz: Bool
    let hasAttempt: Bool
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

        // An empty scored activity is invalid course content, so it cannot
        // dilute the level by entering either numerator or denominator.
        let validProgresses = activityProgresses.values.filter { $0.totalItemCount > 0 }
        hasAttempt = validProgresses.contains(where: \.hasAttempt)

        let activityFractions = validProgresses.map { progress in
            guard progress.hasAttempt else { return 0.0 }
            let score = progress.mastery ?? 0
            return min(max(score / ProgressPolicy.masteryFullScore, 0), 1)
        }
        standardProgress = hasAttempt ? activityFractions.average : nil

        isBlitz = !validProgresses.isEmpty && validProgresses.allSatisfy { progress in
            progress.hasAttempt &&
                (progress.mastery ?? 0) >= ProgressPolicy.blitzThreshold
        }
        coverage = validProgresses.map(\.coverage).average ?? 0
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
