//
//  MockProgress.swift
//  hangulblitz
//
//  Temporary progress states used to exercise the UI.
//

import Foundation

struct LevelDisplayProgress {
    let standardProgress: Double
    let isBlitz: Bool
}

struct ActivityDisplayProgress {
    let hasAttempt: Bool
    let isCompleted: Bool
    let score: Double?
}

enum MockProgress {
    static func level(_ levelID: String) -> LevelDisplayProgress? {
        switch levelID {
        case MockCourse.levelIDs[0]:
            LevelDisplayProgress(standardProgress: 0.15, isBlitz: false)
        case MockCourse.levelIDs[1]:
            LevelDisplayProgress(standardProgress: 1, isBlitz: true)
        default:
            nil
        }
    }

    static func activity(_ activityID: String) -> ActivityDisplayProgress? {
        guard activityID.hasPrefix("\(MockCourse.levelOneID)-") else { return nil }

        if activityID.hasSuffix("get-familiar") || activityID.hasSuffix("connections") {
            return ActivityDisplayProgress(hasAttempt: true, isCompleted: true, score: nil)
        }

        if activityID.hasSuffix("reading") {
            return ActivityDisplayProgress(hasAttempt: true, isCompleted: false, score: 2.5)
        }

        if activityID.hasSuffix("listening") {
            return ActivityDisplayProgress(hasAttempt: true, isCompleted: false, score: 1)
        }

        return nil
    }
}
