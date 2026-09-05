//
//  PracticeRoundSampler.swift
//  hangulblitz
//

import Foundation

enum PracticeSamplingPolicy {
    nonisolated static let fullPoolThreshold = 25
    nonisolated static let preferredRoundSize = 20
    nonisolated static let coverageShare = 0.20
}

struct PracticeSamplingEvidence {
    let practiceCount: Int
    let recentMastery: Double?
    let latestAttemptWasUnsuccessful: Bool
}

enum PracticeRoundSampler {
    static func select(
        texts: [String],
        levelID: String,
        kind: ActivityKind,
        scope: PracticeScope,
        progress: UserProgress
    ) -> [String] {
        var generator = SystemRandomNumberGenerator()
        return select(
            texts: texts,
            levelID: levelID,
            kind: kind,
            scope: scope,
            progress: progress,
            using: &generator
        )
    }

    static func select<R: RandomNumberGenerator>(
        texts: [String],
        levelID: String,
        kind: ActivityKind,
        scope: PracticeScope,
        progress: UserProgress,
        using generator: inout R
    ) -> [String] {
        let uniqueTexts = unique(texts)
        guard kind.isScored else { return uniqueTexts }

        guard uniqueTexts.count > PracticeSamplingPolicy.fullPoolThreshold else {
            return uniqueTexts.shuffled(using: &generator)
        }

        let roundSize = min(PracticeSamplingPolicy.preferredRoundSize, uniqueTexts.count)
        let coverageQuota = min(
            roundSize,
            max(1, Int(ceil(Double(roundSize) * PracticeSamplingPolicy.coverageShare)))
        )
        let evidence = samplingEvidence(
            for: uniqueTexts,
            levelID: levelID,
            kind: kind,
            scope: scope,
            progress: progress
        )
        let randomRanks = Dictionary(
            uniqueKeysWithValues: uniqueTexts.map { ($0, generator.next()) }
        )

        var selected: [String] = []
        var selectedIDs = Set<String>()

        func add(_ candidates: [String], until targetCount: Int) {
            guard targetCount > selected.count else { return }
            for text in candidates {
                guard selected.count < roundSize, selected.count < targetCount else { break }
                if selectedIDs.insert(text).inserted {
                    selected.append(text)
                }
            }
        }

        let coverageCandidates = uniqueTexts.sorted { lhs, rhs in
            let lhsEvidence = evidence[lhs]!
            let rhsEvidence = evidence[rhs]!
            if lhsEvidence.practiceCount != rhsEvidence.practiceCount {
                return lhsEvidence.practiceCount < rhsEvidence.practiceCount
            }
            return randomRanks[lhs]! < randomRanks[rhs]!
        }
        add(Array(coverageCandidates.prefix(coverageQuota)), until: coverageQuota)

        let errorCandidates = uniqueTexts
            .filter { !selectedIDs.contains($0) && evidence[$0]!.latestAttemptWasUnsuccessful }
            .sorted { lhs, rhs in
                let lhsMastery = evidence[lhs]!.recentMastery ?? 0
                let rhsMastery = evidence[rhs]!.recentMastery ?? 0
                if lhsMastery != rhsMastery {
                    return lhsMastery < rhsMastery
                }
                return randomRanks[lhs]! < randomRanks[rhs]!
            }
        add(errorCandidates, until: roundSize)

        let masteryCandidates = uniqueTexts
            .filter { !selectedIDs.contains($0) }
            .sorted { lhs, rhs in
                let lhsMastery = evidence[lhs]!.recentMastery ?? 0
                let rhsMastery = evidence[rhs]!.recentMastery ?? 0
                if lhsMastery != rhsMastery {
                    return lhsMastery < rhsMastery
                }
                return randomRanks[lhs]! < randomRanks[rhs]!
            }
        add(masteryCandidates, until: roundSize)

        selected.shuffle(using: &generator)
        return selected
    }

    private static func unique(_ texts: [String]) -> [String] {
        var seen = Set<String>()
        return texts.filter { seen.insert($0).inserted }
    }

    private static func samplingEvidence(
        for texts: [String],
        levelID: String,
        kind: ActivityKind,
        scope: PracticeScope,
        progress: UserProgress
    ) -> [String: PracticeSamplingEvidence] {
        let levelState = progress.levels[levelID]

        return Dictionary(
            uniqueKeysWithValues: texts.map { text in
                let itemID = LevelItemID(levelID: levelID, text: text)
                let itemProgress = levelState?.items[itemID]

                switch kind {
                case .reading:
                    let directionProgress = itemProgress?.reading
                    return (
                        text,
                        PracticeSamplingEvidence(
                            practiceCount: directionProgress?.practiceCountByScope[scope] ?? 0,
                            recentMastery: directionProgress?.mastery,
                            latestAttemptWasUnsuccessful:
                                directionProgress?.attempts.last?.outcome != nil &&
                                directionProgress?.attempts.last?.outcome != .correct
                        )
                    )

                case .listening:
                    let directionProgress = itemProgress?.listening
                    return (
                        text,
                        PracticeSamplingEvidence(
                            practiceCount: directionProgress?.practiceCountByScope[scope] ?? 0,
                            recentMastery: directionProgress?.mastery,
                            latestAttemptWasUnsuccessful:
                                directionProgress?.attempts.last?.outcome != nil &&
                                directionProgress?.attempts.last?.outcome != .correct
                        )
                    )

                case .guided:
                    return (
                        text,
                        PracticeSamplingEvidence(
                            practiceCount: 0,
                            recentMastery: nil,
                            latestAttemptWasUnsuccessful: false
                        )
                    )
                }
            }
        )
    }
}
