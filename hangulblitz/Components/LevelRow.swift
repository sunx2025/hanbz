//
//  LevelRow.swift
//  hangulblitz
//

import SwiftUI

struct LevelRow: View {
    let level: Level
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
                .foregroundStyle(isSelected ? Color.accentColor : Color.primary)

            Text(verbatim: level.description)
                .font(.footnote)
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                .lineLimit(2)

            if let progress = MockProgress.level(level.id) {
                MasteryIndicator(
                    value: progress.mastery,
                    shape: .star,
                    showsBlitz: progress.isBlitz
                )
                .padding(.top, 1)
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
