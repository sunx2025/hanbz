//
//  ReadingPracticeModels.swift
//  hangulblitz
//

import Foundation
import Observation
import OSLog

struct ReadingPracticeItem: Identifiable, Equatable {
    let text: String
    let romanization: String

    var id: String { text }

    init(text: String) {
        self.text = text
        romanization = KoreanRomanizer.romanize(text)
    }
}

enum ReadingAnswerRevealReason: Equatable {
    case selfAssessment
    case timedOut
}

enum ReadingPracticePhase: Equatable {
    case waitingToStart
    case getReady
    case reading
    case revealingAnswer(ReadingAnswerRevealReason)
    case awaitingAssessment
    case awaitingContinue
    case completed
}

struct ReadingPracticeSubmission {
    let text: String
    let attempt: ReadingAttempt
}

@MainActor
@Observable
final class ReadingPracticeSession {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "hangulblitz",
        category: "ReadingPracticeSession"
    )

    private(set) var sessionID = UUID()
    let levelID: String
    let activity: LearningActivity
    let timeout: TimeInterval

    private let selectedItems: [ReadingPracticeItem]
    private var historicalScores: [String: Double]

    private(set) var items: [ReadingPracticeItem]
    private(set) var currentIndex = 0
    private(set) var phase: ReadingPracticePhase = .waitingToStart
    private(set) var remainingFraction = 1.0
    private(set) var configurationError: String?
    private(set) var submissions: [ReadingPracticeSubmission] = []

    private var pendingRecallTime: TimeInterval?
    private var pendingTimedOutAttempt: ReadingAttempt?

    init(
        levelID: String,
        activity: LearningActivity,
        progress: UserProgress,
        timeout: TimeInterval = ProgressPolicy.readingTimeout
    ) {
        self.levelID = levelID
        self.activity = activity
        self.timeout = timeout

        var seen = Set<String>()
        let uniqueTexts = activity.itemSections
            .flatMap { $0 }
            .map(PracticeAudioCatalog.normalizedText)
            .filter { !$0.isEmpty && seen.insert($0).inserted }

        let selectedItems = uniqueTexts.map(ReadingPracticeItem.init)
        self.selectedItems = selectedItems
        items = selectedItems.shuffled()

        historicalScores = Self.historicalScores(
            for: selectedItems,
            levelID: levelID,
            progress: progress
        )

        if selectedItems.isEmpty {
            let message = "No items found"
            configurationError = message
            Self.logger.error(
                "\(message, privacy: .public) for activity \(activity.id, privacy: .public)"
            )
        }
    }

    var currentItem: ReadingPracticeItem? {
        guard items.indices.contains(currentIndex) else { return nil }
        return items[currentIndex]
    }

    var progress: Double {
        guard !items.isEmpty else { return 0 }
        return Double(currentIndex + 1) / Double(items.count)
    }

    var practiceScore: Double {
        submissions.map(\.attempt.score).average ?? 0
    }

    var recentAverage: Double? {
        let values = submissions.compactMap { historicalScores[$0.text] }
        return values.average
    }

    var comparableCurrentAverage: Double? {
        let values = submissions.compactMap { submission in
            historicalScores[submission.text] == nil ? nil : submission.attempt.score
        }
        return values.average
    }

    var hasImproved: Bool? {
        guard let recentAverage, let comparableCurrentAverage else { return nil }
        return comparableCurrentAverage > recentAverage
    }

    func beginGetReady() {
        guard configurationError == nil else { return }
        clearPendingAnswer()
        remainingFraction = 1
        phase = .getReady
    }

    func beginCurrentItem() {
        guard currentItem != nil else { return }
        clearPendingAnswer()
        remainingFraction = 1
        phase = .reading
    }

    func updateRemainingFraction(_ value: Double) {
        guard phase == .reading else { return }
        remainingFraction = min(max(value, 0), 1)
    }

    func checkAnswer(recallTime: TimeInterval) {
        guard phase == .reading else { return }
        pendingRecallTime = min(max(recallTime, 0), timeout)
        phase = .revealingAnswer(.selfAssessment)
    }

    func timeOut() {
        guard phase == .reading else { return }
        remainingFraction = 0
        pendingTimedOutAttempt = makeAttempt(outcome: .timedOut, recallTime: timeout)
        phase = .revealingAnswer(.timedOut)
    }

    func answerRevealFinished() {
        switch phase {
        case .revealingAnswer(.selfAssessment):
            phase = .awaitingAssessment
        case .revealingAnswer(.timedOut):
            phase = .awaitingContinue
        default:
            break
        }
    }

    func assess(correct: Bool) -> ReadingPracticeSubmission? {
        guard phase == .awaitingAssessment,
              let currentItem,
              let pendingRecallTime else {
            return nil
        }

        let attempt = makeAttempt(
            outcome: correct ? .correct : .incorrect,
            recallTime: pendingRecallTime
        )
        let submission = ReadingPracticeSubmission(text: currentItem.text, attempt: attempt)
        submissions.append(submission)
        moveForward()
        return submission
    }

    func continueAfterTimeout() -> ReadingPracticeSubmission? {
        guard phase == .awaitingContinue,
              let currentItem,
              let pendingTimedOutAttempt else {
            return nil
        }

        let submission = ReadingPracticeSubmission(
            text: currentItem.text,
            attempt: pendingTimedOutAttempt
        )
        submissions.append(submission)
        moveForward()
        return submission
    }

    func resetCurrentItemAfterInterruption() {
        guard phase != .completed else { return }
        clearPendingAnswer()
        remainingFraction = 1
        phase = .waitingToStart
    }

    func restart(progress: UserProgress) {
        sessionID = UUID()
        historicalScores = Self.historicalScores(
            for: selectedItems,
            levelID: levelID,
            progress: progress
        )
        items = shuffledDifferently(from: items)
        currentIndex = 0
        submissions = []
        clearPendingAnswer()
        remainingFraction = 1
        phase = .getReady
    }

    private func moveForward() {
        clearPendingAnswer()
        remainingFraction = 1

        if currentIndex < items.count - 1 {
            currentIndex += 1
            phase = .waitingToStart
        } else {
            phase = .completed
        }
    }

    private func makeAttempt(
        outcome: ReadingAttemptOutcome,
        recallTime: TimeInterval
    ) -> ReadingAttempt {
        ReadingAttempt(
            sessionID: sessionID,
            scope: activity.scope,
            outcome: outcome,
            recallTime: recallTime,
            timeoutThreshold: timeout,
            recordedAt: Date()
        )
    }

    private func clearPendingAnswer() {
        pendingRecallTime = nil
        pendingTimedOutAttempt = nil
    }

    private func shuffledDifferently(
        from previousOrder: [ReadingPracticeItem]
    ) -> [ReadingPracticeItem] {
        guard selectedItems.count > 1 else { return selectedItems }

        for _ in 0..<5 {
            let candidate = selectedItems.shuffled()
            if candidate != previousOrder {
                return candidate
            }
        }

        return Array(previousOrder.dropFirst()) + previousOrder.prefix(1)
    }

    private static func historicalScores(
        for items: [ReadingPracticeItem],
        levelID: String,
        progress: UserProgress
    ) -> [String: Double] {
        let levelState = progress.levels[levelID]
        return Dictionary(
            uniqueKeysWithValues: items.compactMap { item in
                let itemID = LevelItemID(levelID: levelID, text: item.text)
                guard let attempts = levelState?.items[itemID]?.reading.attempts,
                      let average = attempts.suffix(4).map(\.score).average else {
                    return nil
                }
                return (item.text, average)
            }
        )
    }
}

private extension Collection where Element == Double {
    var average: Double? {
        guard !isEmpty else { return nil }
        return reduce(0, +) / Double(count)
    }
}
