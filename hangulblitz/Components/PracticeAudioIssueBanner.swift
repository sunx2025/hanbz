//
//  PracticeAudioIssueBanner.swift
//  hangulblitz
//

import SwiftUI

struct PracticeAudioIssueBanner: View {
    let issue: PracticeAudioIssue

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)

            Text(message)
                .font(.callout.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: .rect(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(.separator), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        .accessibilityElement(children: .combine)
    }

    private var message: String {
        let format: String

        switch issue.kind {
        case .missing:
            format = String(
                localized: "practice.audio.issue.missing",
                comment: "Toast shown when no bundled audio file matches the Korean practice item. The placeholder is the Korean text."
            )
        case .duplicate:
            format = String(
                localized: "practice.audio.issue.duplicate",
                comment: "Toast shown when multiple bundled audio files match the same Korean practice item. The placeholder is the Korean text."
            )
        }

        return String(format: format, issue.text)
    }
}

#Preview("Missing audio") {
    PracticeAudioIssueBanner(
        issue: PracticeAudioIssue(
            kind: .missing,
            text: "아",
            unicodeID: "uC544",
            filenames: []
        )
    )
    .padding()
}
