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
    let isAvailable: Bool
    let overview: CourseArticle?
    let apply: CourseArticle?
    let currentActivities: [LearningActivity]
    let mixedActivities: [LearningActivity]

    var allActivities: [LearningActivity] {
        currentActivities + mixedActivities
    }

    func activity(id: String) -> LearningActivity? {
        allActivities.first { $0.id == id }
    }
}

struct CourseArticle: Equatable {
    let sections: [CourseArticleSection]
}

struct CourseArticleSection: Equatable {
    let title: String
    let blocks: [CourseArticleBlock]
}

enum CourseArticleBlock: Equatable {
    case paragraph(String)
    case note(String)
    case table(CourseArticleTable)
}

struct CourseArticleTable: Equatable {
    let rows: [CourseArticleTableRow]
}

struct CourseArticleTableRow: Equatable {
    let hangul: String
    let note: String
    let audio: CourseArticleAudio
}

enum CourseArticleAudio: Equatable {
    /// The page's playback strategy may pronounce this row.
    case available

    /// The course author explicitly marked this row as having no sound.
    case unavailable
}

struct LearningActivity: Identifiable {
    let id: String
    let kind: ActivityKind
    let scope: PracticeScope
    let title: String
    let description: String
    let itemSections: [[String]]
    let contrasts: [[String]]

    var items: [String] {
        itemSections.flatMap { $0 }
    }
}

enum PracticeScope: String, Codable {
    case current
    case mixed
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
