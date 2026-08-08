//
//  GuidedPracticeModels.swift
//  hangulblitz
//

import Foundation
import Observation

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
    private let sourceItems: [String]

    private(set) var items: [GuidedPracticeItem]
    private(set) var currentIndex = 0
    private(set) var isComplete = false

    init(activity: LearningActivity) {
        let activityItems = activity.items.isEmpty
            ? ["ㅏ", "ㅓ", "ㅗ", "ㅜ", "ㅡ", "ㅣ"]
            : activity.items
        sourceItems = activityItems
        items = activityItems.map { GuidedPracticeItem(text: $0) }
    }

    var currentItem: GuidedPracticeItem {
        items[currentIndex]
    }

    var progress: Double {
        guard !items.isEmpty else { return 0 }
        return Double(currentIndex + 1) / Double(items.count)
    }

    var canMovePrevious: Bool {
        currentIndex > 0
    }

    func movePrevious() {
        guard canMovePrevious else { return }
        currentIndex -= 1
    }

    func moveNext() {
        if currentIndex == items.count - 1 {
            isComplete = true
        } else {
            currentIndex += 1
        }
    }

    func restart() {
        items = sourceItems.shuffled().map { GuidedPracticeItem(text: $0) }
        currentIndex = 0
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
