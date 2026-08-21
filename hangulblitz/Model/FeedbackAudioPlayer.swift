//
//  FeedbackAudioPlayer.swift
//  hangulblitz
//

import AVFoundation
import Foundation
import OSLog

@MainActor
final class FeedbackAudioPlayer {
    enum Sound {
        case success
        case error

        fileprivate var filename: String {
            switch self {
            case .success: "success-chime"
            case .error: "error-pop"
            }
        }
    }

    private var player: AVAudioPlayer?

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "hangulblitz",
        category: "FeedbackAudio"
    )

    func play(_ sound: Sound) {
        stop()

        guard let url = Bundle.main.url(
            forResource: sound.filename,
            withExtension: "mp3"
        ) else {
            Self.logger.error("Feedback audio missing: \(sound.filename, privacy: .public).mp3")
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            self.player = player
            player.play()
        } catch {
            Self.logger.error(
                "Unable to play feedback audio \(sound.filename, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    func stop() {
        player?.stop()
        player = nil
    }
}
