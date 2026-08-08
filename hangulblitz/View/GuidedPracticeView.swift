//
//  GuidedPracticeView.swift
//  hangulblitz
//

import SwiftUI

struct GuidedPracticeView: View {
    let activity: LearningActivity
    let readingActivity: LearningActivity?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase

    @State private var session: GuidedPracticeSession
    @State private var audioPlayer = PracticeAudioPlayer()
    @State private var isPreparing = true
    @State private var preparationTask: Task<Void, Never>?
    @State private var showsReadingPlaceholder = false

    init(activity: LearningActivity, readingActivity: LearningActivity?) {
        self.activity = activity
        self.readingActivity = readingActivity
        _session = State(initialValue: GuidedPracticeSession(activity: activity))
    }

    var body: some View {
        PracticeSessionShell(
            title: activity.title,
            background: session.isComplete
                ? Color(.systemBackground)
                : Color(.systemGroupedBackground),
            close: close
        ) {
            if isPreparing {
                GuidedPracticeGetReadyView()
            } else if session.isComplete {
                GuidedPracticeCompletionView(
                    canStartReading: readingActivity != nil,
                    startReading: { showsReadingPlaceholder = true },
                    learnAgain: restart
                )
            } else {
                practiceContent
            }
        }
        .navigationDestination(isPresented: $showsReadingPlaceholder) {
            if let readingActivity {
                ActivityPlaceholderView(title: readingActivity.title)
            }
        }
        .overlay(alignment: .top) {
            if let issue = audioPlayer.audioIssue {
                PracticeAudioIssueBanner(issue: issue)
                    .frame(maxWidth: PracticeLayout.flashCardMaxWidth)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: issue.id) {
                        try? await Task.sleep(for: .seconds(3))
                        guard !Task.isCancelled else { return }
                        audioPlayer.dismissIssue(id: issue.id)
                    }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: audioPlayer.audioIssue?.id)
        .onAppear(perform: beginPreparation)
        .onDisappear {
            cancelPreparation()
            audioPlayer.stop()
        }
        .onChange(of: scenePhase) {
            switch scenePhase {
            case .active:
                if isPreparing {
                    beginPreparation()
                } else if !session.isComplete {
                    playCurrentItem()
                }
            case .inactive, .background:
                cancelPreparation()
                audioPlayer.stop()
            @unknown default:
                cancelPreparation()
                audioPlayer.stop()
            }
        }
    }

    private var practiceContent: some View {
        VStack(spacing: 32) {
            // Progress bar section
            VStack {
                PracticeProgressBar(value: session.progress)
            }
            .frame(minHeight: 8, maxHeight: horizontalSizeClass == .regular ? .infinity : nil, alignment: .center)
            .padding(.horizontal)

            // Flashcard section
            GuidedFlashCard(
                item: session.currentItem,
                audioPlayer: audioPlayer
            )
            .frame(
                maxWidth: PracticeLayout.flashCardMaxWidth,
                maxHeight: PracticeLayout.flashCardMaxHeight
            )
            .aspectRatio(PracticeLayout.flashCardAspectRatio, contentMode: .fit)
            .layoutPriority(2)

            // Buttons section
            VStack {
                HStack(spacing: 16) {
                    AppButton(
                        style: .outlined,
                        size: .large,
                        width: .fill,
                        action: movePrevious
                    ) {
                        Text("practice.previous", comment: "Button that moves to the previous practice card.")
                    }
                    .disabled(!session.canMovePrevious)

                    AppButton(
                        style: .filled,
                        size: .large,
                        width: .fill,
                        action: moveNext
                    ) {
                        Text("practice.next", comment: "Button that moves to the next practice card.")
                    }
                }
            }
            .padding(.horizontal)
            .frame(minHeight: 56, maxHeight: horizontalSizeClass == .regular ? .infinity : nil, alignment: .center)
        }
        .frame(
            maxWidth: PracticeLayout.flashCardMaxWidth,
            maxHeight: .infinity,
            alignment: .top
        )
        .padding(.horizontal)
        .frame(maxWidth: .infinity)
        .onAppear(perform: playCurrentItem)
    }

    private func movePrevious() {
        session.movePrevious()
        playCurrentItem()
    }

    private func moveNext() {
        audioPlayer.stop()
        session.moveNext()
        if !session.isComplete {
            playCurrentItem()
        }
    }

    private func restart() {
        audioPlayer.stop()
        session.restart()
        isPreparing = true
        beginPreparation()
    }

    private func playCurrentItem() {
        guard !isPreparing, !session.isComplete, scenePhase == .active else {
            return
        }
        audioPlayer.playPrepared(text: session.currentItem.text)
    }

    private func beginPreparation() {
        guard isPreparing, scenePhase == .active else { return }

        cancelPreparation()
        let currentText = session.currentItem.text
        preparationTask = Task { @MainActor in
            do {
                async let minimumDelay: Void = Task.sleep(for: .seconds(1))
                async let audioPreparation: Void = audioPlayer.prepare(text: currentText)
                _ = try await (minimumDelay, audioPreparation)
            } catch {
                return
            }

            guard !Task.isCancelled, isPreparing, scenePhase == .active else {
                return
            }

            preparationTask = nil
            isPreparing = false
        }
    }

    private func cancelPreparation() {
        preparationTask?.cancel()
        preparationTask = nil
    }

    private func close() {
        cancelPreparation()
        audioPlayer.stop()
        dismiss()
    }
}

private struct GuidedPracticeGetReadyView: View {
    var body: some View {
        GeometryReader { geo in
            VStack {
                Text(
                    "guided.get_ready",
                    comment: "Brief message shown before guided practice begins automatically. Markdown may emphasise part of the phrase."
                )
                .font(.title)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }
            .frame(height: geo.size.height * 0.7)
            .frame(maxWidth: .infinity)
        }
    }
}

private struct GuidedFlashCard: View {
    let item: GuidedPracticeItem
    let audioPlayer: PracticeAudioPlayer

    var body: some View {
//        VStack(spacing: 24) {
//            Text("guided.instruction", comment: "Instruction shown at the top of a guided practice flashcard.")
//                .font(.headline)
//
//            Spacer(minLength: 8)
//
//            Text(verbatim: item.text)
//                .font(.system(size: 160, weight: .regular))
//                .minimumScaleFactor(0.34)
//                .lineLimit(1)
//                .frame(maxWidth: .infinity)
//                .accessibilityLabel(Text(verbatim: item.text))
//
//            Spacer(minLength: 8)
//
//            AudioPlaybackIndicator(
//                isPlaying: audioPlayer.isPlaying,
//                samples: audioPlayer.samples,
//                romanization: item.romanization,
//                replay: audioPlayer.play
//            )
//        }
        Group {
            GeometryReader { geo in
                // the flash content layout is a 9 row grid
                let rowHeight = geo.size.height / 9
                VStack (spacing: 0) {
                    Text("guided.instruction", comment: "Instruction shown at the top of a guided practice flashcard.")
                        .font(.headline)
                        .frame(height: rowHeight)
                        //.background(Color.gray)
                    
                    // placeholder
                    Color.clear
                        .frame(height: rowHeight)
                        .frame(height: rowHeight)
                    
                    Text(verbatim: item.text)
                        .font(.system(size: 160, weight: .regular))
                        .minimumScaleFactor(0.34)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, maxHeight: rowHeight * 5)
                        .accessibilityLabel(Text(verbatim: item.text))
                    
                    VStack {
                        AudioPlaybackIndicator(
                            isPlaying: audioPlayer.isPlaying,
                            samples: audioPlayer.samples,
                            romanization: item.romanization,
                            replay: { audioPlayer.playPrepared(text: item.text) }
                        )
                    }
                    .frame(height: rowHeight * 2, alignment: .top)
                    //.background(Color.gray)
                }
            }
            
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 32))
        .overlay {
            RoundedRectangle(cornerRadius: 32)
                .stroke(Color(.separator), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.05), radius: 16, y: 4)
    }
}

private struct GuidedPracticeCompletionView: View {
    let canStartReading: Bool
    let startReading: () -> Void
    let learnAgain: () -> Void

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    Spacer()

                    Text("guided.completion.title", comment: "Congratulatory heading after guided practice is completed.")
                        .font(.title.weight(.semibold))

                    Text("guided.completion.message", comment: "Message shown after guided practice is completed.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Spacer()
                }
                .frame(height: geometry.size.height / 2)

                VStack(spacing: 16) {
                    Spacer()

                    AppButton(style: .filled, size: .medium, action: startReading) {
                        Text("activity.reading.title", comment: "Title for the reading self-assessment activity.")
                    }
                    .disabled(!canStartReading)

                    AppButton(style: .muted, size: .medium, action: learnAgain) {
                        Text("guided.completion.learn_again", comment: "Button that restarts guided practice from the beginning.")
                    }

                    Spacer()
                }
                .frame(height: geometry.size.height / 2)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
        }
    }
}

#Preview("Guided practice get ready") {
    GuidedPracticeGetReadyView()
        .background(Color(.systemGroupedBackground))
        .environment(\.locale, Locale(identifier: "en_AU"))
}

#Preview("Guided practice completion") {
    GuidedPracticeCompletionView(
        canStartReading: true,
        startReading: {},
        learnAgain: {}
    )
    .background(Color(.systemBackground))
    .environment(\.locale, Locale(identifier: "en_AU"))
}

#Preview("Guided practice") {
    let locale = Locale(identifier: "en_AU")
    let level = MockCourse.course(locale: locale).levels[0]

    NavigationStack {
        GuidedPracticeView(
            activity: level.currentActivities[0],
            readingActivity: level.currentActivities[1]
        )
    }
    .environment(\.locale, locale)
}
