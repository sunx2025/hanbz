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

struct Overview: Equatable {
    let sections: [OverviewSection]
}

struct OverviewSection: Equatable {
    let title: String
    let blocks: [OverviewBlock]
}

enum OverviewBlock: Equatable {
    case paragraph(String)
    case note(String)
    case table(OverviewTable)
}

struct OverviewTable: Equatable {
    let rows: [OverviewTableRow]
}

struct OverviewTableRow: Equatable {
    let hangul: String
    let note: String
    let audio: OverviewAudio
}

enum OverviewAudio: Equatable {
    /// Resolve the conventional bundled audio file from the Hangul text.
    case lookup

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

enum PracticeScope {
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
