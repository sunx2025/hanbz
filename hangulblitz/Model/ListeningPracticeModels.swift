//
//  ListeningPracticeModels.swift
//  hangulblitz
//

import Foundation
import Observation
import OSLog

struct ListeningPracticeItem: Identifiable, Equatable {
    let text: String
    let options: [String]

    var id: String { text }
}

enum ListeningFeedback: Equatable {
    case correct(selected: String)
    case incorrect(selected: String)
    case notSure
    case timedOut

    var selectedOption: String? {
        switch self {
        case let .correct(selected), let .incorrect(selected): selected
        case .notSure, .timedOut: nil
        }
    }
}

enum ListeningPracticePhase: Equatable {
    case waitingToStart
    case getReady
    case prompting
    case answering
    case feedback(ListeningFeedback)
    case awaitingContinue
    case completed
}

struct ListeningPracticeSubmission {
    let text: String
    let attempt: ListeningAttempt
}

@MainActor
@Observable
final class ListeningPracticeSession {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "hangulblitz",
        category: "ListeningPracticeSession"
    )

    private(set) var sessionID = UUID()
    let levelID: String
    let activity: LearningActivity
    let timeout: TimeInterval

    private let selectedTexts: [String]
    private var historicalScores: [String: Double]

    private(set) var items: [ListeningPracticeItem]
    private(set) var currentIndex = 0
    private(set) var phase: ListeningPracticePhase = .waitingToStart
    private(set) var remainingFraction = 1.0
    private(set) var configurationError: String?
    private(set) var submissions: [ListeningPracticeSubmission] = []

    init(
        levelID: String,
        activity: LearningActivity,
        progress: UserProgress,
        timeout: TimeInterval = ProgressPolicy.listeningTimeout
    ) {
        self.levelID = levelID
        self.activity = activity
        self.timeout = timeout

        var seen = Set<String>()
        let texts = activity.itemSections
            .flatMap { $0 }
            .map(PracticeAudioCatalog.normalizedText)
            .filter { !$0.isEmpty && seen.insert($0).inserted }

        selectedTexts = texts
        items = Self.makeItems(texts: texts, contrasts: activity.contrasts)
        historicalScores = Self.historicalScores(
            for: texts,
            levelID: levelID,
            progress: progress
        )

        if texts.isEmpty {
            reportConfigurationError("No items found")
        } else if items.contains(where: { $0.options.isEmpty }) {
            reportConfigurationError("No listening options found")
        }
    }

    var currentItem: ListeningPracticeItem? {
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
        submissions.compactMap { historicalScores[$0.text] }.average
    }

    var comparableCurrentAverage: Double? {
        submissions.compactMap { submission in
            historicalScores[submission.text] == nil ? nil : submission.attempt.score
        }.average
    }

    var hasImproved: Bool? {
        guard let recentAverage, let comparableCurrentAverage else { return nil }
        return comparableCurrentAverage > recentAverage
    }

    func beginGetReady() {
        guard configurationError == nil else { return }
        remainingFraction = 1
        phase = .getReady
    }

    func beginCurrentItem() {
        guard currentItem != nil else { return }
        remainingFraction = 1
        phase = .prompting
    }

    func promptFinished() {
        guard phase == .prompting else { return }
        phase = .answering
    }

    func updateRemainingFraction(_ value: Double) {
        guard phase == .answering else { return }
        remainingFraction = min(max(value, 0), 1)
    }

    func select(
        _ option: String,
        responseTime: TimeInterval,
        isScorable: Bool
    ) -> ListeningPracticeSubmission? {
        guard (phase == .prompting || phase == .answering),
              let currentItem else {
            return nil
        }

        let isCorrect = option == currentItem.text
        phase = isCorrect
            ? .feedback(.correct(selected: option))
            : .feedback(.incorrect(selected: option))

        guard isScorable else { return nil }
        return appendSubmission(
            text: currentItem.text,
            outcome: isCorrect ? .correct : .incorrect,
            responseTime: min(max(responseTime, 0), timeout)
        )
    }

    func chooseNotSure(isScorable: Bool) -> ListeningPracticeSubmission? {
        guard phase == .answering, let currentItem else { return nil }
        phase = .feedback(.notSure)
        guard isScorable else { return nil }
        return appendSubmission(
            text: currentItem.text,
            outcome: .notSure,
            responseTime: elapsedTime
        )
    }

    func timeOut(isScorable: Bool) -> ListeningPracticeSubmission? {
        guard phase == .answering, let currentItem else { return nil }
        remainingFraction = 0
        phase = .feedback(.timedOut)
        guard isScorable else { return nil }
        return appendSubmission(
            text: currentItem.text,
            outcome: .timedOut,
            responseTime: timeout
        )
    }

    func feedbackFinished() {
        guard case let .feedback(feedback) = phase else { return }
        if feedback == .timedOut {
            phase = .awaitingContinue
        } else {
            moveForward()
        }
    }

    func continueAfterTimeout() {
        guard phase == .awaitingContinue else { return }
        moveForward()
    }

    func advanceAnsweredCardAfterInterruption() {
        switch phase {
        case .feedback, .awaitingContinue:
            moveForward()
        default:
            break
        }
    }

    func resetCurrentItemAfterInterruption() {
        guard phase != .completed else { return }
        remainingFraction = 1
        phase = .waitingToStart
    }

    func restart(progress: UserProgress) {
        sessionID = UUID()
        historicalScores = Self.historicalScores(
            for: selectedTexts,
            levelID: levelID,
            progress: progress
        )
        items = Self.makeItems(texts: selectedTexts, contrasts: activity.contrasts)
        currentIndex = 0
        submissions = []
        remainingFraction = 1
        phase = .getReady
    }

    private var elapsedTime: TimeInterval {
        timeout * (1 - remainingFraction)
    }

    private func appendSubmission(
        text: String,
        outcome: ListeningAttemptOutcome,
        responseTime: TimeInterval
    ) -> ListeningPracticeSubmission {
        let submission = ListeningPracticeSubmission(
            text: text,
            attempt: ListeningAttempt(
                sessionID: sessionID,
                scope: activity.scope,
                outcome: outcome,
                responseTime: responseTime,
                timeoutThreshold: timeout,
                recordedAt: Date()
            )
        )
        submissions.append(submission)
        return submission
    }

    private func moveForward() {
        remainingFraction = 1
        if currentIndex < items.count - 1 {
            currentIndex += 1
            phase = .waitingToStart
        } else {
            phase = .completed
        }
    }

    private func reportConfigurationError(_ message: String) {
        configurationError = message
        Self.logger.error(
            "\(message, privacy: .public) for activity \(self.activity.id, privacy: .public)"
        )
    }

    private static func makeItems(
        texts: [String],
        contrasts: [[String]]
    ) -> [ListeningPracticeItem] {
        let normalizedContrasts = contrasts.map { set in
            var seen = Set<String>()
            return set
                .map(PracticeAudioCatalog.normalizedText)
                .filter { !$0.isEmpty && seen.insert($0).inserted }
        }

        return texts.shuffled().map { target in
            var seen = Set([target])
            var distractors = normalizedContrasts
                .filter { $0.contains(target) }
                .flatMap { $0 }
                .filter { $0 != target && seen.insert($0).inserted }
                .shuffled()

            if distractors.count > 3 {
                distractors = Array(distractors.prefix(3))
            }

            if distractors.count < 3 {
                let fillers = texts
                    .filter { seen.insert($0).inserted }
                    .shuffled()
                distractors.append(contentsOf: fillers.prefix(3 - distractors.count))
            }

            return ListeningPracticeItem(
                text: target,
                options: ([target] + distractors).shuffled()
            )
        }
    }

    private static func historicalScores(
        for texts: [String],
        levelID: String,
        progress: UserProgress
    ) -> [String: Double] {
        let levelState = progress.levels[levelID]
        return Dictionary(
            uniqueKeysWithValues: texts.compactMap { text in
                let itemID = LevelItemID(levelID: levelID, text: text)
                guard let attempts = levelState?.items[itemID]?.listening.attempts,
                      let average = attempts.suffix(4).map(\.score).average else {
                    return nil
                }
                return (text, average)
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
