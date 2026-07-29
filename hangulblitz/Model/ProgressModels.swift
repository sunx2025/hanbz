//
//  ProgressModels.swift
//  hangulblitz
//

import Foundation

struct User: Identifiable {
    let id: String
    var name: String
    var progress: UserProgress
}

struct UserProgress {
    var levels: [String: LevelProgress] = [:]
}

struct LevelProgress {
    var activities: [String: ActivityProgress] = [:]
}

struct ActivityProgress {
    var isCompleted = false
    var items: [String: ItemProgress] = [:]
}

struct ItemProgress {
    var results: [AttemptResult] = []
}

struct AttemptResult {
    let outcome: AttemptOutcome
    let responseTime: TimeInterval
}

enum AttemptOutcome {
    case correct
    case incorrect
    case notSure
    case timedOut
}
