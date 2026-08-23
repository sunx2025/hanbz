//
//  ProgressStore.swift
//  hangulblitz
//

import Foundation
import OSLog

enum ProgressStore {
    static let defaultUserID = "default"

    private static let schemaVersion = 1
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "hangulblitz",
        category: "ProgressStorage"
    )

    private struct StoredUserProgress: Codable {
        let schemaVersion: Int
        let progress: UserProgress
    }

    static func load(userID: String) -> UserProgress {
        do {
            let url = try progressFileURL(userID: userID)
            guard FileManager.default.fileExists(atPath: url.path) else {
                return UserProgress()
            }

            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let storedProgress = try decoder.decode(StoredUserProgress.self, from: data)

            guard storedProgress.schemaVersion == schemaVersion else {
                logger.error(
                    "Unsupported progress schema version: \(storedProgress.schemaVersion, privacy: .public)"
                )
                return UserProgress()
            }

            return storedProgress.progress
        } catch {
            logger.error("Could not load progress: \(error.localizedDescription, privacy: .public)")
            return UserProgress()
        }
    }

    @discardableResult
    static func save(_ progress: UserProgress, userID: String) -> Bool {
        do {
            let storedProgress = StoredUserProgress(
                schemaVersion: schemaVersion,
                progress: progress
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

            let data = try encoder.encode(storedProgress)
            try data.write(to: progressFileURL(userID: userID), options: .atomic)
            return true
        } catch {
            logger.error("Could not save progress: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    @discardableResult
    static func reset(userID: String) -> Bool {
        do {
            let url = try progressFileURL(userID: userID)
            guard FileManager.default.fileExists(atPath: url.path) else {
                return true
            }

            try FileManager.default.removeItem(at: url)
            return true
        } catch {
            logger.error("Could not reset progress: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private static func progressFileURL(userID: String) throws -> URL {
        let directory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        .appending(path: "HangulBlitz", directoryHint: .isDirectory)
        .appending(path: "Progress", directoryHint: .isDirectory)

        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        return directory.appending(
            path: "\(safeFilenameComponent(userID)).json",
            directoryHint: .notDirectory
        )
    }

    private static func safeFilenameComponent(_ userID: String) -> String {
        let allowedCharacters = CharacterSet.alphanumerics.union(
            CharacterSet(charactersIn: "-_")
        )

        guard !userID.isEmpty,
              let encodedUserID = userID.addingPercentEncoding(
                  withAllowedCharacters: allowedCharacters
              ),
              !encodedUserID.isEmpty else {
            return defaultUserID
        }

        return encodedUserID
    }
}
