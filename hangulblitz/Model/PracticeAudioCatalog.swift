//
//  PracticeAudioCatalog.swift
//  hangulblitz
//

import Foundation

enum PracticeAudioLookupResult: Sendable {
    case found(url: URL, unicodeID: String)
    case missing(unicodeID: String)
    case duplicate(unicodeID: String, urls: [URL])
}

actor PracticeAudioCatalog {
    static let shared = PracticeAudioCatalog(resourceURL: Bundle.main.resourceURL)

    private let resourceURL: URL?
    private var indexTask: Task<[String: [URL]], Never>?

    init(resourceURL: URL?) {
        self.resourceURL = resourceURL
    }

    func resolve(text: String) async -> PracticeAudioLookupResult {
        let unicodeID = Self.unicodeID(for: text)
        let urls = await audioIndex()[unicodeID, default: []]

        switch urls.count {
        case 0:
            return .missing(unicodeID: unicodeID)
        case 1:
            return .found(url: urls[0], unicodeID: unicodeID)
        default:
            return .duplicate(unicodeID: unicodeID, urls: urls)
        }
    }

    nonisolated static func unicodeID(for text: String) -> String {
        let normalized = normalizedText(text)
        guard !normalized.isEmpty else { return "u0" }

        return normalized.unicodeScalars
            .map { "u" + String($0.value, radix: 16).uppercased() }
            .joined(separator: "-")
    }

    nonisolated static func normalizedText(_ text: String) -> String {
        text
            .precomposedStringWithCanonicalMapping
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    private func audioIndex() async -> [String: [URL]] {
        if let indexTask {
            return await indexTask.value
        }

        let resourceURL = resourceURL
        let task = Task.detached(priority: .userInitiated) {
            Self.buildIndex(resourceURL: resourceURL)
        }
        indexTask = task
        return await task.value
    }

    nonisolated private static func buildIndex(resourceURL: URL?) -> [String: [URL]] {
        guard let resourceURL else { return [:] }

        let keys: [URLResourceKey] = [.isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(
            at: resourceURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return [:]
        }

        var index: [String: [URL]] = [:]

        for case let url as URL in enumerator {
            guard url.pathExtension.caseInsensitiveCompare("mp3") == .orderedSame,
                  let unicodeID = unicodeID(fromAudioURL: url) else {
                continue
            }

            index[unicodeID, default: []].append(url)
        }

        return index.mapValues { urls in
            urls.sorted { $0.lastPathComponent < $1.lastPathComponent }
        }
    }

    nonisolated private static func unicodeID(fromAudioURL url: URL) -> String? {
        let filename = url.deletingPathExtension().lastPathComponent
        guard let underscore = filename.lastIndex(of: "_") else { return nil }

        let candidate = String(filename[filename.index(after: underscore)...])
        let parts = candidate.split(separator: "-", omittingEmptySubsequences: false)
        guard !parts.isEmpty else { return nil }

        var normalizedParts: [String] = []
        normalizedParts.reserveCapacity(parts.count)

        for part in parts {
            guard let prefix = part.first,
                  prefix == "u" || prefix == "U" else {
                return nil
            }

            let digits = part.dropFirst()
            guard !digits.isEmpty,
                  digits.unicodeScalars.allSatisfy({ scalar in
                      switch scalar.value {
                      case 48...57, 65...70, 97...102:
                          true
                      default:
                          false
                      }
                  }) else {
                return nil
            }

            normalizedParts.append("u" + digits.uppercased())
        }

        return normalizedParts.joined(separator: "-")
    }
}
