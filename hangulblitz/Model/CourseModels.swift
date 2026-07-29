//
//  CourseModels.swift
//  hangulblitz
//

import Foundation

struct Course: Identifiable {
    let id: String
    let levels: [Level]

    func level(id: String) -> Level? {
        levels.first { $0.id == id }
    }
}

struct Level: Identifiable {
    let id: String
    let number: Int
    let title: String
    let description: String
    let overview: Overview?
    let currentActivities: [LearningActivity]
    let mixedActivities: [LearningActivity]

    var allActivities: [LearningActivity] {
        currentActivities + mixedActivities
    }

    func activity(id: String) -> LearningActivity? {
        allActivities.first { $0.id == id }
    }
}

struct Overview {}

struct LearningActivity: Identifiable {
    let id: String
    let kind: ActivityKind
    let title: String
    let description: String
    let items: [String]
    let contrasts: [[String]]
}

enum ActivityKind {
    case guided
    case reading
    case listening

    var isScored: Bool {
        switch self {
        case .guided:
            false
        case .reading, .listening:
            true
        }
    }
}
