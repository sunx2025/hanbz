//
//  LevelTitle.swift
//  hangulblitz
//

import SwiftUI

struct LevelTitle: View {
    let level: Level

    @Environment(\.locale) private var locale

    var body: some View {
        Text(verbatim: level.displayTitle(locale: locale))
    }
}

extension Level {
    func displayTitle(locale: Locale) -> String {
        let format = String(
            localized: "level.title.format",
            defaultValue: "Level %lld: %@",
            locale: locale,
            comment: "Level heading. The first placeholder is the level number and the second is its course-defined title."
        )

        return String(
            format: format,
            locale: locale,
            arguments: [number, title]
        )
    }
}
