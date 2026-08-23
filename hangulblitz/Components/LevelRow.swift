//
//  LevelRow.swift
//  hangulblitz
//

import SwiftUI

struct LevelRow: View {
    let level: Level
    let progress: LevelDisplayProgress?
    var isSelected = false
    var presentation: Presentation = .card

    enum Presentation {
        case card
        case sidebar
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            LevelTitle(level: level)
                .font(.headline)
                //.foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                .foregroundStyle(
                    level.isAvailable
                        ? (isSelected ? .accent : Color.primary)
                        : Color.secondary
                )

            Group {
                if level.isAvailable {
                    Text(verbatim: level.description)
                } else {
                    Text(
                        "level.availability.coming_soon",
                        comment: "Status shown instead of a level description when its course content is not yet available."
                    )
                }
            }
                .font(.footnote)
                //.foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                .foregroundStyle(isSelected ? .accent : Color.secondary)
                .lineLimit(2)

            if level.isAvailable, let progress {
                LevelProgressIndicator(
                    progress: progress.standardProgress,
                    isBlitz: progress.isBlitz
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(background)
        //.clipShape(.rect(cornerRadius: presentation == .card ? 16 : 12))
        .clipShape(.rect(cornerRadius: 16))
        .contentShape(.rect)
    }

    private var background: Color {
        if isSelected {
            return Color("Group Background")
        }

        return presentation == .card
            ? Color(.secondarySystemGroupedBackground)
            : Color.clear
    }
}
