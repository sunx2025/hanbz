//
//  GuidedPracticeModels.swift
//  hangulblitz
//

import Foundation
import Observation
import OSLog

struct GuidedPracticeItem: Identifiable, Equatable {
    let id: UUID
    let text: String
    let romanization: String

    init(text: String, romanization: String? = nil) {
        id = UUID()
        self.text = text
        self.romanization = romanization ?? KoreanRomanizer.romanize(text)
    }
}

@MainActor
@Observable
final class GuidedPracticeSession {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "hangulblitz",
        category: "GuidedPracticeSession"
    )

    private let sourceSections: [[String]]

    private(set) var sections: [[GuidedPracticeItem]]
    private(set) var currentSectionIndex = 0
    private(set) var currentItemIndex = 0
    private(set) var isComplete = false
    private(set) var configurationError: String?

    init(activity: LearningActivity) {
        let nonemptySections = activity.itemSections.filter { !$0.isEmpty }
        sourceSections = nonemptySections
        sections = nonemptySections.map { section in
            section.map { GuidedPracticeItem(text: $0) }
        }

        if nonemptySections.isEmpty {
            let message = "No items found"
            configurationError = message
            Self.logger.error("\(message, privacy: .public) for activity \(activity.id, privacy: .public)")
        }
    }

    var currentItem: GuidedPracticeItem? {
        guard sections.indices.contains(currentSectionIndex),
              sections[currentSectionIndex].indices.contains(currentItemIndex) else {
            return nil
        }
        return sections[currentSectionIndex][currentItemIndex]
    }

    var currentSectionItems: [GuidedPracticeItem] {
        guard sections.indices.contains(currentSectionIndex) else { return [] }
        return sections[currentSectionIndex]
    }

    var sectionNumber: Int {
        currentSectionIndex + 1
    }

    var sectionCount: Int {
        sections.count
    }

    var progress: Double {
        let totalItemCount = sections.reduce(0) { $0 + $1.count }
        guard totalItemCount > 0 else { return 0 }

        let precedingItemCount = sections
            .prefix(currentSectionIndex)
            .reduce(0) { $0 + $1.count }
        return Double(precedingItemCount + currentItemIndex + 1) / Double(totalItemCount)
    }

    var canMovePrevious: Bool {
        currentSectionIndex > 0 || currentItemIndex > 0
    }

    var isOnLastItem: Bool {
        guard currentItem != nil else { return false }
        return currentSectionIndex == sections.count - 1
            && currentItemIndex == currentSectionItems.count - 1
    }

    func movePrevious() {
        guard canMovePrevious else { return }

        if currentItemIndex > 0 {
            currentItemIndex -= 1
        } else {
            currentSectionIndex -= 1
            currentItemIndex = sections[currentSectionIndex].count - 1
        }
    }

    func moveNext() {
        guard currentItem != nil else { return }

        if currentItemIndex < currentSectionItems.count - 1 {
            currentItemIndex += 1
        } else if currentSectionIndex < sections.count - 1 {
            currentSectionIndex += 1
            currentItemIndex = 0
        } else {
            isComplete = true
        }
    }

    func restart() {
        // Guided practice preserves both section order and item order.
        sections = sourceSections.map { section in
            section.map { GuidedPracticeItem(text: $0) }
        }
        currentSectionIndex = 0
        currentItemIndex = 0
        isComplete = false
    }
}

enum KoreanRomanizer {
    // This deterministic fallback mirrors the audio tool's written-Hangul
    // spelling logic. Course configuration can override it when the desired
    // learner-facing pronunciation differs because of Korean sound changes.
    static func romanize(_ text: String) -> String {
        let normalized = text.precomposedStringWithCanonicalMapping
        let result = normalized.unicodeScalars.map { romanize($0) }.joined()
        return result.isEmpty ? text : result
    }

    private static func romanize(_ scalar: Unicode.Scalar) -> String {
        let value = scalar.value

        if value >= 0xAC00, value <= 0xD7A3 {
            let offset = Int(value - 0xAC00)
            let initial = offset / 588
            let medial = (offset % 588) / 28
            let final = offset % 28
            return initials[initial] + medials[medial] + finals[final]
        }

        if let compatibility = compatibilityJamo[value] {
            return compatibility
        }

        if CharacterSet.whitespacesAndNewlines.contains(scalar) {
            return " "
        }

        return String(scalar).lowercased()
    }

    private static let initials = [
        "g", "kk", "n", "d", "tt", "r", "m", "b", "pp", "s", "ss", "",
        "j", "jj", "ch", "k", "t", "p", "h"
    ]

    private static let medials = [
        "a", "ae", "ya", "yae", "eo", "e", "yeo", "ye", "o", "wa", "wae",
        "oe", "yo", "u", "wo", "we", "wi", "yu", "eu", "ui", "i"
    ]

    private static let finals = [
        "", "g", "kk", "gs", "n", "nj", "nh", "d", "l", "lg", "lm", "lb",
        "ls", "lt", "lp", "lh", "m", "b", "bs", "s", "ss", "ng", "j", "ch",
        "k", "t", "p", "h"
    ]

    private static let compatibilityJamo: [UInt32: String] = [
        0x3131: "g", 0x3132: "kk", 0x3134: "n", 0x3137: "d", 0x3138: "tt",
        0x3139: "r", 0x3141: "m", 0x3142: "b", 0x3143: "pp", 0x3145: "s",
        0x3146: "ss", 0x3147: "ng", 0x3148: "j", 0x3149: "jj", 0x314A: "ch",
        0x314B: "k", 0x314C: "t", 0x314D: "p", 0x314E: "h",
        0x314F: "a", 0x3150: "ae", 0x3151: "ya", 0x3152: "yae", 0x3153: "eo",
        0x3154: "e", 0x3155: "yeo", 0x3156: "ye", 0x3157: "o", 0x3158: "wa",
        0x3159: "wae", 0x315A: "oe", 0x315B: "yo", 0x315C: "u", 0x315D: "wo",
        0x315E: "we", 0x315F: "wi", 0x3160: "yu", 0x3161: "eu", 0x3162: "ui",
        0x3163: "i"
    ]
}
