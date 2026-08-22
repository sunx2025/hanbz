//
//  CourseContentParser.swift
//  hangulblitz
//

import Foundation

struct LocalizedLevelContent: Equatable {
    let id: String
    let title: String
    let description: String
    let overview: Overview?
}

enum CourseContentParser {
    static func parse(_ source: String) throws -> [String: LocalizedLevelContent] {
        let lines = normalizedLines(source)
        var result: [String: LocalizedLevelContent] = [:]
        var cursor = 0

        while cursor < lines.count {
            skipEmptyLinesAndRules(lines, cursor: &cursor)
            guard cursor < lines.count else { break }

            guard let levelID = headingText(lines[cursor], level: 1) else {
                throw error("Expected a level ID heading", line: cursor)
            }
            let levelLine = cursor
            cursor += 1

            skipEmptyLines(lines, cursor: &cursor)
            guard cursor < lines.count,
                  let title = headingText(lines[cursor], level: 2) else {
                throw error("Expected a level title heading", line: cursor)
            }
            cursor += 1

            skipEmptyLines(lines, cursor: &cursor)
            let description = try parseLevelDescription(lines, cursor: &cursor)
            var overview: Overview?

            while cursor < lines.count, headingText(lines[cursor], level: 1) == nil {
                if isRule(lines[cursor]) {
                    cursor += 1
                    break
                }

                guard let moduleID = headingText(lines[cursor], level: 3) else {
                    cursor += 1
                    continue
                }
                cursor += 1

                if moduleID == "title.overview" {
                    overview = try parseOverview(lines, cursor: &cursor)
                } else {
                    skipModule(lines, cursor: &cursor)
                }
            }

            guard result[levelID] == nil else {
                throw error("Duplicate level ID \(levelID)", line: levelLine)
            }
            result[levelID] = LocalizedLevelContent(
                id: levelID,
                title: title,
                description: description,
                overview: overview
            )
        }

        return result
    }

    private static func parseLevelDescription(
        _ lines: [String],
        cursor: inout Int
    ) throws -> String {
        let start = cursor
        var descriptionLines: [String] = []

        while cursor < lines.count,
              !lines[cursor].trimmingCharacters(in: .whitespaces).isEmpty,
              !isHeading(lines[cursor]),
              !isRule(lines[cursor]) {
            descriptionLines.append(cleanTextLine(lines[cursor]))
            cursor += 1
        }

        guard !descriptionLines.isEmpty else {
            throw error("Expected a level description", line: start)
        }
        return descriptionLines.joined(separator: "\n")
    }

    private static func parseOverview(
        _ lines: [String],
        cursor: inout Int
    ) throws -> Overview {
        var sections: [OverviewSection] = []

        while cursor < lines.count {
            skipEmptyLines(lines, cursor: &cursor)
            guard cursor < lines.count,
                  headingText(lines[cursor], level: 1) == nil,
                  headingText(lines[cursor], level: 3) == nil,
                  !isRule(lines[cursor]) else {
                break
            }

            guard let title = headingText(lines[cursor], level: 4) else {
                throw error("Overview content must begin with a section heading", line: cursor)
            }
            cursor += 1
            let blocks = try parseSectionBlocks(lines, cursor: &cursor)
            sections.append(OverviewSection(title: title, blocks: blocks))
        }

        guard !sections.isEmpty else {
            throw error("Overview must contain at least one section", line: cursor)
        }
        return Overview(sections: sections)
    }

    private static func parseSectionBlocks(
        _ lines: [String],
        cursor: inout Int
    ) throws -> [OverviewBlock] {
        var blocks: [OverviewBlock] = []

        while cursor < lines.count {
            skipEmptyLines(lines, cursor: &cursor)
            guard cursor < lines.count,
                  headingText(lines[cursor], level: 4) == nil,
                  headingText(lines[cursor], level: 3) == nil,
                  headingText(lines[cursor], level: 1) == nil,
                  !isRule(lines[cursor]) else {
                break
            }

            if isTableLine(lines[cursor]) {
                blocks.append(.table(try parseTable(lines, cursor: &cursor)))
            } else if isQuoteLine(lines[cursor]) {
                blocks.append(.note(parseTextBlock(lines, cursor: &cursor, quote: true)))
            } else {
                blocks.append(.paragraph(parseTextBlock(lines, cursor: &cursor, quote: false)))
            }
        }

        return blocks
    }

    private static func parseTextBlock(
        _ lines: [String],
        cursor: inout Int,
        quote: Bool
    ) -> String {
        var textLines: [String] = []

        while cursor < lines.count {
            let line = lines[cursor]
            guard !line.trimmingCharacters(in: .whitespaces).isEmpty,
                  !isHeading(line),
                  !isRule(line),
                  !isTableLine(line),
                  isQuoteLine(line) == quote else {
                break
            }

            let content: String
            if quote {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                content = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
            } else {
                content = cleanTextLine(line)
            }
            textLines.append(content)
            cursor += 1
        }

        // In this course dialect, an author-entered line break is meaningful.
        // This preserves formula lines while SwiftUI still wraps long prose.
        return textLines.joined(separator: "\n")
    }

    private static func parseTable(
        _ lines: [String],
        cursor: inout Int
    ) throws -> OverviewTable {
        let headerLine = cursor
        let headers = tableCells(lines[cursor])
        guard headers.map({ $0.lowercased() }) == ["hangul", "note", "sound"] else {
            throw error("Overview tables must use hangul | note | sound columns", line: cursor)
        }
        cursor += 1

        guard cursor < lines.count,
              isTableSeparator(tableCells(lines[cursor])) else {
            throw error("Expected a Markdown table separator", line: cursor)
        }
        cursor += 1

        var rows: [OverviewTableRow] = []
        while cursor < lines.count, isTableLine(lines[cursor]) {
            let cells = tableCells(lines[cursor])
            guard cells.count == 3 else {
                throw error("Expected three table cells", line: cursor)
            }

            let audio: OverviewAudio
            switch cells[2] {
            case "":
                audio = .lookup
            case "-":
                audio = .unavailable
            default:
                throw error("Sound must be blank or -", line: cursor)
            }

            guard !cells[0].isEmpty else {
                throw error("Hangul table cell cannot be empty", line: cursor)
            }
            rows.append(
                OverviewTableRow(
                    hangul: cells[0],
                    note: cells[1],
                    audio: audio
                )
            )
            cursor += 1
        }

        guard !rows.isEmpty else {
            throw error("Overview table must contain at least one row", line: headerLine)
        }
        return OverviewTable(rows: rows)
    }

    private static func skipModule(_ lines: [String], cursor: inout Int) {
        while cursor < lines.count,
              headingText(lines[cursor], level: 3) == nil,
              headingText(lines[cursor], level: 1) == nil,
              !isRule(lines[cursor]) {
            cursor += 1
        }
    }

    private static func normalizedLines(_ source: String) -> [String] {
        source
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{2028}", with: "\n")
            .components(separatedBy: "\n")
    }

    private static func headingText(_ line: String, level: Int) -> String? {
        let prefix = String(repeating: "#", count: level) + " "
        guard line.hasPrefix(prefix),
              !line.hasPrefix("#" + prefix) else {
            return nil
        }
        let value = String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : value
    }

    private static func isHeading(_ line: String) -> Bool {
        (1...6).contains { headingText(line, level: $0) != nil }
    }

    private static func isRule(_ line: String) -> Bool {
        let compact = line.filter { !$0.isWhitespace }
        return compact.count >= 3 && compact.allSatisfy { $0 == "-" }
    }

    private static func isQuoteLine(_ line: String) -> Bool {
        line.trimmingCharacters(in: .whitespaces).hasPrefix(">")
    }

    private static func isTableLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("|") && trimmed.hasSuffix("|")
    }

    private static func tableCells(_ line: String) -> [String] {
        let pieces = line.split(separator: "|", omittingEmptySubsequences: false)
        guard pieces.count >= 2 else { return [] }
        return pieces.dropFirst().dropLast().map {
            $0.trimmingCharacters(in: .whitespaces)
        }
    }

    private static func isTableSeparator(_ cells: [String]) -> Bool {
        cells.count == 3 && cells.allSatisfy { cell in
            let dashes = cell.trimmingCharacters(in: CharacterSet(charactersIn: ":"))
            return !dashes.isEmpty && dashes.allSatisfy { $0 == "-" }
        }
    }

    private static func cleanTextLine(_ line: String) -> String {
        line.trimmingCharacters(in: .whitespaces)
    }

    private static func skipEmptyLines(_ lines: [String], cursor: inout Int) {
        while cursor < lines.count,
              lines[cursor].trimmingCharacters(in: .whitespaces).isEmpty {
            cursor += 1
        }
    }

    private static func skipEmptyLinesAndRules(_ lines: [String], cursor: inout Int) {
        while cursor < lines.count {
            if lines[cursor].trimmingCharacters(in: .whitespaces).isEmpty || isRule(lines[cursor]) {
                cursor += 1
            } else {
                break
            }
        }
    }

    private static func error(_ message: String, line: Int) -> CourseContentParserError {
        CourseContentParserError(message: message, line: line + 1)
    }
}

struct CourseContentParserError: LocalizedError, Equatable {
    let message: String
    let line: Int

    var errorDescription: String? {
        "Line \(line): \(message)"
    }
}

enum CourseContentLoader {
    static func load(
        localization: String,
        bundle: Bundle = .main
    ) throws -> [String: LocalizedLevelContent] {
        guard let url = bundle.url(
            forResource: "hangul-content",
            withExtension: "md",
            subdirectory: nil,
            localization: localization
        ) else {
            throw CourseContentLoaderError.missingResource(localization: localization)
        }

        return try CourseContentParser.parse(String(contentsOf: url, encoding: .utf8))
    }
}

enum CourseContentLoaderError: LocalizedError {
    case missingResource(localization: String)

    var errorDescription: String? {
        switch self {
        case let .missingResource(localization):
            "Missing localized hangul-content.md for \(localization)"
        }
    }
}
