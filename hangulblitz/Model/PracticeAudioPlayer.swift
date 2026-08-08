//
//  PracticeAudioPlayer.swift
//  hangulblitz
//

import AVFoundation
import Foundation
import Observation
import OSLog

struct PracticeAudioIssue: Identifiable, Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case missing
        case duplicate
    }

    let id = UUID()
    let kind: Kind
    let text: String
    let unicodeID: String
    let filenames: [String]
}

@MainActor
@Observable
final class PracticeAudioPlayer {
    private(set) var isPlaying = false
    private(set) var samples: [CGFloat] = Array(repeating: 0.08, count: 40)
    private(set) var audioIssue: PracticeAudioIssue?

    private let audioCatalog: PracticeAudioCatalog
    private var player: AVAudioPlayer?
    private var preparedText: String?
    private var preparedUnicodeID: String?
    private var meteringTask: Task<Void, Never>?
    private var loadingTask: Task<Void, Never>?
    private var loadGeneration = 0

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "hangulblitz",
        category: "PracticeAudio"
    )

    init(audioCatalog: PracticeAudioCatalog = .shared) {
        self.audioCatalog = audioCatalog
    }

    /// Resolves and decodes an item without starting playback. Guided practice
    /// uses this during its Get Ready state to hide first-play latency.
    func prepare(text: String) async {
        beginNewLoad(resetSamples: true)
        let generation = loadGeneration
        await load(text: text, generation: generation, startsPlayback: false)
    }

    /// Resolves, prepares, and plays an item. The shared catalog scans the App
    /// bundle only once per process, then serves subsequent lookups from memory.
    func play(text: String) {
        beginNewLoad(resetSamples: true)
        let generation = loadGeneration

        loadingTask = Task { [weak self] in
            guard let self else { return }
            await load(text: text, generation: generation, startsPlayback: true)
        }
    }

    /// Plays an already prepared item, or falls back to a normal lookup if the
    /// prepared player was discarded after a scene or card transition.
    func playPrepared(text: String) {
        let normalizedText = PracticeAudioCatalog.normalizedText(text)
        guard preparedText == normalizedText,
              let unicodeID = preparedUnicodeID,
              player != nil else {
            play(text: text)
            return
        }

        audioIssue = nil
        startPreparedPlayback(text: normalizedText, unicodeID: unicodeID)
    }

    func stop(resetSamples: Bool = false) {
        loadGeneration += 1
        loadingTask?.cancel()
        loadingTask = nil
        resetPlayer(resetSamples: resetSamples)
        audioIssue = nil
    }

    func dismissIssue(id: PracticeAudioIssue.ID) {
        guard audioIssue?.id == id else { return }
        audioIssue = nil
    }

    private func beginNewLoad(resetSamples: Bool) {
        loadGeneration += 1
        loadingTask?.cancel()
        loadingTask = nil
        resetPlayer(resetSamples: resetSamples)
        audioIssue = nil
    }

    private func load(
        text: String,
        generation: Int,
        startsPlayback: Bool
    ) async {
        let normalizedText = PracticeAudioCatalog.normalizedText(text)
        let result = await audioCatalog.resolve(text: normalizedText)

        guard !Task.isCancelled, generation == loadGeneration else { return }

        switch result {
        case let .found(url, unicodeID):
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.isMeteringEnabled = true
                player.prepareToPlay()

                self.player = player
                preparedText = normalizedText
                preparedUnicodeID = unicodeID

                if startsPlayback {
                    startPreparedPlayback(text: normalizedText, unicodeID: unicodeID)
                }
            } catch {
                reportMissing(text: normalizedText, unicodeID: unicodeID)
            }

        case let .missing(unicodeID):
            reportMissing(text: normalizedText, unicodeID: unicodeID)

        case let .duplicate(unicodeID, urls):
            reportDuplicate(text: normalizedText, unicodeID: unicodeID, urls: urls)
        }

        if generation == loadGeneration {
            loadingTask = nil
        }
    }

    private func startPreparedPlayback(text: String, unicodeID: String) {
        guard let player else {
            reportMissing(text: text, unicodeID: unicodeID)
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio)
            try session.setActive(true)

            meteringTask?.cancel()
            meteringTask = nil
            samples = Array(repeating: 0.08, count: 40)
            player.stop()
            player.currentTime = 0

            guard player.play() else {
                reportMissing(text: text, unicodeID: unicodeID)
                return
            }

            audioIssue = nil
            isPlaying = true
            startMetering()
        } catch {
            reportMissing(text: text, unicodeID: unicodeID)
        }
    }

    private func resetPlayer(resetSamples: Bool) {
        meteringTask?.cancel()
        meteringTask = nil
        player?.stop()
        player = nil
        preparedText = nil
        preparedUnicodeID = nil
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
        guard let player else {
            isPlaying = false
            meteringTask?.cancel()
            meteringTask = nil
            return
        }

        guard player.isPlaying else {
            isPlaying = false
            meteringTask?.cancel()
            meteringTask = nil
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

    private func reportMissing(text: String, unicodeID: String) {
        resetPlayer(resetSamples: false)
        audioIssue = PracticeAudioIssue(
            kind: .missing,
            text: text,
            unicodeID: unicodeID,
            filenames: []
        )
        Self.logger.error("Audio missing: \(text, privacy: .public) (\(unicodeID, privacy: .public))")
    }

    private func reportDuplicate(text: String, unicodeID: String, urls: [URL]) {
        resetPlayer(resetSamples: false)
        let filenames = urls.map(\.lastPathComponent)
        audioIssue = PracticeAudioIssue(
            kind: .duplicate,
            text: text,
            unicodeID: unicodeID,
            filenames: filenames
        )
        Self.logger.error(
            "Duplicate audio: \(text, privacy: .public) (\(unicodeID, privacy: .public)): \(filenames.joined(separator: ", "), privacy: .public)"
        )
    }
}
