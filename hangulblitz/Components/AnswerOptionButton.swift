//
//  AnswerOptionButton.swift
//  hangulblitz
//

import SwiftUI

enum AnswerOptionState {
    case normal
    case correct
    case incorrect
    case disabled
}

struct AnswerOptionButton: View {
    let text: String
    let state: AnswerOptionState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(verbatim: text)
                .font(.title2.bold())
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 56)
                .contentShape(.rect)
        }
        .buttonStyle(AnswerOptionButtonStyle(state: state))
        .disabled(state != .normal)
    }
}

private struct AnswerOptionButtonStyle: ButtonStyle {
    let state: AnswerOptionState

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foregroundStyle)
            .background(backgroundStyle)
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(borderStyle, lineWidth: 1)
            }
            .clipShape(.rect(cornerRadius: 8))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }

    private var foregroundStyle: Color {
        switch state {
        case .correct:
            .onAccent
        case .normal, .incorrect, .disabled:
            .primary
        }
    }

    private var backgroundStyle: Color {
        switch state {
        case .normal, .disabled:
            .clear
        case .correct:
            .accentColor
        case .incorrect:
            Color(.systemGray4)
        }
    }

    private var borderStyle: Color {
        switch state {
        case .normal:
            .accentColor
        case .correct:
            .accentColor
        case .incorrect:
            Color(.systemGray4)
        case .disabled:
            .accentColor.opacity(0.35)
        }
    }
}
