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
            if session.isComplete {
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
        .onAppear(perform: playCurrentItem)
        .onDisappear {
            audioPlayer.stop()
        }
        .onChange(of: scenePhase) {
            switch scenePhase {
            case .active:
                guard !session.isComplete else { return }
                playCurrentItem()
            case .inactive, .background:
                audioPlayer.stop()
            @unknown default:
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
        session.restart()
        playCurrentItem()
    }

    private func playCurrentItem() {
        audioPlayer.play()
    }

    private func close() {
        audioPlayer.stop()
        dismiss()
    }

}

private struct GuidedFlashCard: View {
    let item: GuidedPracticeItem
    let audioPlayer: PracticeAudioPlayer

    var body: some View {
        VStack(spacing: 24) {
            Text("guided.instruction", comment: "Instruction shown at the top of a guided practice flashcard.")
                .font(.headline)

            Spacer(minLength: 8)

            Text(verbatim: item.text)
                .font(.system(size: 160, weight: .regular))
                .minimumScaleFactor(0.34)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(Text(verbatim: item.text))

            Spacer(minLength: 8)

            AudioPlaybackIndicator(
                isPlaying: audioPlayer.isPlaying,
                samples: audioPlayer.samples,
                romanization: item.romanization,
                replay: audioPlayer.play
            )
        }
        .padding(.vertical, 32)
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
