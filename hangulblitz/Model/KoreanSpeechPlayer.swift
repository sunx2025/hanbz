//
//  KoreanSpeechPlayer.swift
//  hangulblitz
//

import AVFAudio
import Foundation
import Observation
import OSLog

struct KoreanSpeechIssue: Identifiable, Equatable {
    let id = UUID()
}

@MainActor
@Observable
final class KoreanSpeechPlayer {
    private(set) var issue: KoreanSpeechIssue?

    private let synthesizer = AVSpeechSynthesizer()

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "hangulblitz",
        category: "KoreanSpeech"
    )

    func play(text: String) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        guard let voice = preferredVoice() else {
            synthesizer.stopSpeaking(at: .immediate)
            issue = KoreanSpeechIssue()
            Self.logger.error("No Korean speech synthesis voice is installed")
            return
        }

        synthesizer.stopSpeaking(at: .immediate)

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = 0.33
        utterance.pitchMultiplier = 1
        utterance.volume = 1

        issue = nil
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        issue = nil
    }

    func dismissIssue(id: KoreanSpeechIssue.ID) {
        guard issue?.id == id else { return }
        issue = nil
    }

    private func preferredVoice() -> AVSpeechSynthesisVoice? {
        let koreanVoices = AVSpeechSynthesisVoice.speechVoices().filter {
            $0.language.caseInsensitiveCompare("ko-KR") == .orderedSame
        }

        return koreanVoices.first {
            $0.name.caseInsensitiveCompare("Yuna") == .orderedSame
                || $0.identifier.localizedCaseInsensitiveContains("Yuna")
        } ?? AVSpeechSynthesisVoice(language: "ko-KR")
    }
}
