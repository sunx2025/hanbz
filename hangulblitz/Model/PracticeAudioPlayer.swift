//
//  PracticeAudioPlayer.swift
//  hangulblitz
//

import AVFoundation
import Foundation
import Observation

@MainActor
@Observable
final class PracticeAudioPlayer {
    private(set) var isPlaying = false
    private(set) var samples: [CGFloat] = Array(repeating: 0.08, count: 40)
    private(set) var isAudioMissing = false

    private var player: AVAudioPlayer?
    private var meteringTask: Task<Void, Never>?

    func play() {
        stop(resetSamples: true)

        // TODO: Replace this debug-only resource with the production lookup:
        // NFC-normalise the item, build its Unicode ID, then match the one
        // bundled audio filename whose final underscore section is that ID.
        guard let url = placeholderAudioURL() else {
            isAudioMissing = true
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio)
            try session.setActive(true)

            let player = try AVAudioPlayer(contentsOf: url)
            player.isMeteringEnabled = true
            player.prepareToPlay()

            guard player.play() else {
                isAudioMissing = true
                return
            }

            self.player = player
            isAudioMissing = false
            isPlaying = true
            startMetering()
        } catch {
            isAudioMissing = true
            isPlaying = false
        }
    }

    func stop(resetSamples: Bool = false) {
        meteringTask?.cancel()
        meteringTask = nil
        player?.stop()
        player = nil
        isPlaying = false

        if resetSamples {
            samples = Array(repeating: 0.08, count: 40)
        }
    }

    private func startMetering() {
        meteringTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))
                guard !Task.isCancelled, let self else { return }
                updateMeter()
            }
        }
    }

    private func updateMeter() {
        guard let player, player.isPlaying else {
            stop()
            return
        }

        player.updateMeters()
        let decibels = player.averagePower(forChannel: 0)
        let linearPower = pow(10, Double(decibels) / 20)
        let visuallyBoostedPower = min(max(pow(linearPower, 0.45), 0.06), 1)

        samples.append(CGFloat(visuallyBoostedPower))
        if samples.count > 40 {
            samples.removeFirst(samples.count - 40)
        }
    }

    private func placeholderAudioURL() -> URL? {
        Bundle.main.url(
            forResource: "_debug0000",
            withExtension: "mp3",
            subdirectory: "Audio"
        ) ?? Bundle.main.url(forResource: "_debug0000", withExtension: "mp3")
    }
}
