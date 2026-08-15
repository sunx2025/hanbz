//
//  ReadingPracticeView.swift
//  hangulblitz
//

import SwiftUI

struct ReadingPracticeView: View {
    let levelID: String
    let activity: LearningActivity

    @Binding private var progress: UserProgress

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("readingPractice.hasSeenHowToPlay")
    private var hasSeenHowToPlay = false

    @State private var session: ReadingPracticeSession
    @State private var audioPlayer = PracticeAudioPlayer()
    @State private var hasAppeared = false
    @State private var readyLightCount = 0
    @State private var cardStartedAt: ContinuousClock.Instant?
    @State private var readyTask: Task<Void, Never>?
    @State private var timerTask: Task<Void, Never>?
    @State private var showsHelp = false
    @State private var helpStartsPractice = false
    @State private var showsPausedOverlay = false

    init(
        levelID: String,
        activity: LearningActivity,
        progress: Binding<UserProgress>
    ) {
        self.levelID = levelID
        self.activity = activity
        _progress = progress
        _session = State(
            initialValue: ReadingPracticeSession(
                levelID: levelID,
                activity: activity,
                progress: progress.wrappedValue
            )
        )
    }

    var body: some View {
        PracticeSessionShell(
            title: activity.title,
            background: session.phase == .completed
                ? Color(.systemBackground)
                : Color(.systemGroupedBackground),
            close: close
        ) {
            mainContent
                .blur(radius: showsPausedOverlay ? 12 : 0)
                .allowsHitTesting(!showsPausedOverlay)
                .accessibilityHidden(showsPausedOverlay)
        }
        .overlay {
            if showsPausedOverlay {
                ReadingPracticePausedView(
                    resume: resumeAfterInterruption,
                    quit: close
                )
                .transition(.opacity)
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
        .sheet(isPresented: $showsHelp) {
            let help = ReadingPracticeHelpView(
                usesTabletPresentation: horizontalSizeClass == .regular,
                start: finishHelp
            )

            if horizontalSizeClass == .regular {
                help
                    .interactiveDismissDisabled()
                    .presentationSizing(.fitted)
            } else {
                help
                    .interactiveDismissDisabled()
                    .presentationDetents([.large])
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showsPausedOverlay)
        .animation(.easeInOut(duration: 0.2), value: audioPlayer.audioIssue?.id)
        .onAppear(perform: startOnce)
        .onDisappear(perform: stopTransientWork)
        .onChange(of: scenePhase, handleScenePhase)
    }

    @ViewBuilder
    private var mainContent: some View {
        if let configurationError = session.configurationError {
            ContentUnavailableView {
                Text(verbatim: configurationError)
            }
        } else {
            switch session.phase {
            case .waitingToStart:
                Color.clear
            case .getReady:
                ReadingPracticeGetReadyView(
                    activeLightCount: readyLightCount,
                    showHelp: openHelp
                )
            case .completed:
                ReadingPracticeCompletionView(
                    score: session.practiceScore,
                    messageKey: completionMessageKey,
                    practiseAgain: restart
                )
            case .reading,
                    .revealingAnswer,
                    .awaitingAssessment,
                    .awaitingContinue:
                practiceContent
            }
        }
    }

    private var practiceContent: some View {
        VStack(spacing: 32) {
            VStack {
                PracticeProgressBar(value: session.progress)
            }
            .frame(
                minHeight: 8,
                maxHeight: horizontalSizeClass == .regular ? .infinity : nil,
                alignment: .center
            )
            .padding(.horizontal)

            if let currentItem = session.currentItem {
                ReadingFlashCard(
                    item: currentItem,
                    phase: session.phase,
                    audioPlayer: audioPlayer,
                    replay: replayAnswer
                )
                .frame(
                    maxWidth: PracticeLayout.flashCardMaxWidth,
                    maxHeight: PracticeLayout.flashCardMaxHeight
                )
                .aspectRatio(PracticeLayout.flashCardAspectRatio, contentMode: .fit)
                .layoutPriority(2)
            }

            VStack {
                actionArea
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal)
            .frame(
                minHeight: 56,
                maxHeight: horizontalSizeClass == .regular ? .infinity : nil,
                alignment: .center
            )
        }
        .frame(
            maxWidth: PracticeLayout.flashCardMaxWidth,
            maxHeight: .infinity,
            alignment: .top
        )
        .padding(.horizontal)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var actionArea: some View {
        switch session.phase {
        case .reading:
            TimedAppButton(
                remainingFraction: session.remainingFraction,
                action: checkAnswer
            ) {
                Text(
                    "reading.action.check_answer",
                    comment: "Button that stops the reading timer and reveals the answer."
                )
            }

        case .revealingAnswer(.selfAssessment):
            AppButton(style: .filled, size: .large, width: .fill, action: {}) {
                Text(
                    "reading.action.check_answer",
                    comment: "Button that stops the reading timer and reveals the answer."
                )
            }
            .disabled(true)

        case .awaitingAssessment:
            HStack(spacing: 16) {
                AppButton(
                    style: .outlined,
                    size: .large,
                    width: .fill,
                    action: { assess(correct: false) }
                ) {
                    Text(
                        "reading.action.not_quite",
                        comment: "Self-assessment button indicating the learner did not read the item correctly."
                    )
                }

                AppButton(
                    style: .filled,
                    size: .large,
                    width: .fill,
                    action: { assess(correct: true) }
                ) {
                    Text(
                        "reading.action.got_it",
                        comment: "Self-assessment button indicating the learner read the item correctly."
                    )
                }
            }

        case .revealingAnswer(.timedOut):
            AppButton(style: .muted, size: .large, width: .fill, action: {}) {
                Text(
                    "reading.action.timeout",
                    comment: "Disabled button shown while the answer audio plays after time expires."
                )
            }
            .disabled(true)

        case .awaitingContinue:
            AppButton(
                style: .filled,
                size: .large,
                width: .fill,
                action: continueAfterTimeout
            ) {
                Text(
                    "reading.action.continue",
                    comment: "Button that advances after a timed-out reading card."
                )
            }

        default:
            EmptyView()
        }
    }

    private var completionMessageKey: LocalizedStringKey {
        if session.hasImproved == true {
            return "reading.completion.faster"
        }

        switch session.practiceScore {
        case ProgressPolicy.blitzThreshold...:
            return "reading.completion.great_consistency"
        case 4...:
            return "reading.completion.nice_progress"
        case 2...:
            return "reading.completion.keep_it_up"
        default:
            return "reading.completion.keep_practising"
        }
    }

    private func startOnce() {
        guard !hasAppeared else { return }
        hasAppeared = true

        if hasSeenHowToPlay {
            beginGetReady()
        } else {
            helpStartsPractice = true
            showsHelp = true
        }
    }

    private func beginGetReady() {
        stopTransientWork()
        session.beginGetReady()
        readyLightCount = 0

        // this rhythm feels good: 0.8s/0.8s/0.8s/0.7s
        readyTask = Task { @MainActor in
            for lightCount in 1...3 {
                do {
                    try await Task.sleep(for: .milliseconds(800))
                } catch {
                    return
                }
                guard !Task.isCancelled, scenePhase == .active else { return }
                readyLightCount = lightCount
            }

            do {
                try await Task.sleep(for: .milliseconds(700))
            } catch {
                return
            }

            guard !Task.isCancelled, scenePhase == .active else { return }
            readyTask = nil
            beginTimedCard()
        }
    }

    private func beginTimedCard() {
        timerTask?.cancel()
        audioPlayer.stop()
        session.beginCurrentItem()

        let clock = ContinuousClock()
        let startedAt = clock.now
        cardStartedAt = startedAt

        timerTask = Task { @MainActor in
            while !Task.isCancelled {
                let elapsed = startedAt.duration(to: clock.now).timeInterval

                if elapsed >= session.timeout {
                    timerTask = nil
                    handleTimeout()
                    return
                }

                session.updateRemainingFraction(1 - elapsed / session.timeout)

                do {
                    try await Task.sleep(for: .milliseconds(16))
                } catch {
                    return
                }
            }
        }
    }

    private func checkAnswer() {
        guard let cardStartedAt else { return }
        let elapsed = cardStartedAt.duration(to: ContinuousClock.now).timeInterval
        cancelTimer()
        session.checkAnswer(recallTime: elapsed)
        revealAnswer()
    }

    private func handleTimeout() {
        cancelTimer()
        session.timeOut()
        revealAnswer()
    }

    private func revealAnswer() {
        guard let currentItem = session.currentItem else { return }
        audioPlayer.play(text: currentItem.text) {
            session.answerRevealFinished()
        }
    }

    private func replayAnswer() {
        guard let currentItem = session.currentItem else { return }
        audioPlayer.play(text: currentItem.text)
    }

    private func assess(correct: Bool) {
        guard let submission = session.assess(correct: correct) else { return }
        record(submission)
        advanceIfNeeded()
    }

    private func continueAfterTimeout() {
        guard let submission = session.continueAfterTimeout() else { return }
        record(submission)
        advanceIfNeeded()
    }

    private func record(_ submission: ReadingPracticeSubmission) {
        progress.record(
            submission.attempt,
            levelID: levelID,
            text: submission.text
        )
        progress.save()
    }

    private func advanceIfNeeded() {
        audioPlayer.stop()
        if session.phase != .completed {
            beginTimedCard()
        }
    }

    private func restart() {
        stopTransientWork()
        session.restart(progress: progress)
        beginGetReady()
    }

    private func openHelp() {
        let startsPractice = session.phase == .waitingToStart || session.phase == .getReady
        stopTransientWork()
        session.resetCurrentItemAfterInterruption()
        helpStartsPractice = startsPractice
        showsHelp = true
    }

    private func finishHelp() {
        showsHelp = false
        hasSeenHowToPlay = true

        if helpStartsPractice {
            beginGetReady()
        } else {
            beginTimedCard()
        }
    }

    private func handleScenePhase(_ oldPhase: ScenePhase, _ newPhase: ScenePhase) {
        guard newPhase != .active,
              hasAppeared,
              !showsHelp,
              session.phase != .completed,
              session.configurationError == nil else {
            return
        }

        stopTransientWork()
        session.resetCurrentItemAfterInterruption()
        showsPausedOverlay = true
    }

    private func resumeAfterInterruption() {
        showsPausedOverlay = false
        beginTimedCard()
    }

    private func cancelTimer() {
        timerTask?.cancel()
        timerTask = nil
        cardStartedAt = nil
    }

    private func stopTransientWork() {
        readyTask?.cancel()
        readyTask = nil
        cancelTimer()
        audioPlayer.stop()
    }

    private func close() {
        stopTransientWork()
        dismiss()
    }
}

private struct ReadingPracticeGetReadyView: View {
    let activeLightCount: Int
    let showHelp: () -> Void

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    Spacer()

                    Text(
                        "reading.get_ready.instruction",
                        comment: "Instruction shown above the reading practice get-ready lights."
                    )
                    .font(.callout)

                    HStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { index in
                            Text(verbatim: index < activeLightCount ? "🔴" : "⚪️")
                        }
                    }
                    .font(.title2)
                    .accessibilityHidden(true)

                    Text(
                        "reading.get_ready.title",
                        comment: "Title shown while the reading practice countdown lights run."
                    )
                    .font(.title)
                    .foregroundStyle(.secondary)

                    Spacer()
                }
                .frame(height: geometry.size.height * 0.76)

                ReadingHowToPlayButton(action: showHelp)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct ReadingFlashCard: View {
    let item: ReadingPracticeItem
    let phase: ReadingPracticePhase
    let audioPlayer: PracticeAudioPlayer
    let replay: () -> Void

    private var isAnswerVisible: Bool {
        switch phase {
        case .revealingAnswer, .awaitingAssessment, .awaitingContinue:
            true
        default:
            false
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let rowHeight = geometry.size.height / 9

            VStack(spacing: 0) {
                Text(
                    isAnswerVisible
                        ? "reading.instruction.check_answer"
                        : "reading.instruction.read_aloud",
                    comment: "Instruction at the top of a reading practice flashcard."
                )
                .font(.headline)
                .frame(height: rowHeight)

                Color.clear
                    .frame(height: rowHeight)
                
                Text(verbatim: item.text)
                    .font(.system(size: 160, weight: .regular))
                    .foregroundColor(phase == .awaitingAssessment ? .secondary : .primary) // this effect is to explore ideas of reducing confusion when awaiting assessment
                    .minimumScaleFactor(0.34)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, maxHeight: rowHeight * 5)
                    .accessibilityLabel(Text(verbatim: item.text))

                Group {
                    if isAnswerVisible {
                        AudioPlaybackIndicator(
                            isPlaying: audioPlayer.isPlaying,
                            isLoading: audioPlayer.isLoading,
                            samples: audioPlayer.samples,
                            romanization: item.romanization,
                            replay: replay
                        )
                    } else {
                        Color.clear
                            .frame(minHeight: 80)
                    }
                }
                .frame(height: rowHeight * 2, alignment: .top)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 32))
        .overlay {
            RoundedRectangle(cornerRadius: 32)
                .stroke(Color(.separator), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.05), radius: 16, y: 4)
    }
}

private struct ReadingHowToPlayButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                Text(
                    "reading.help.action",
                    comment: "Button that opens instructions for reading practice."
                )
            } icon: {
                Image(systemName: "questionmark.circle.fill")
            }
            .font(.footnote)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.tint)
    }
}

private struct ReadingPracticeHelpView: View {
    let usesTabletPresentation: Bool
    let start: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(
                "reading.help.title",
                comment: "Title of the reading practice instruction sheet."
            )
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .center)
            //.frame(height: 48)

            Text(
                "reading.help.goal",
                comment: "Goal explained in the reading practice instruction sheet."
            )
            .font(.body)
            .fixedSize(horizontal: false, vertical: true)

            Text(
                "reading.help.each_card",
                comment: "Heading before the per-card reading practice instructions."
            )
            .font(.body)

            VStack(alignment: .leading, spacing: 6) {
                Text(
                    "reading.help.step_one.title",
                    comment: "Heading for the first reading practice instruction step."
                )
                .font(.headline)

                Text(
                    "reading.help.step_one.body",
                    comment: "Explanation of the first reading practice instruction step."
                )
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(
                    "reading.help.step_two.title",
                    comment: "Heading for the second reading practice instruction step."
                )
                .font(.headline)

                Text(
                    "reading.help.step_two.body",
                    comment: "Explanation of the second reading practice instruction step."
                )
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            AppButton(style: .outlined, size: .medium, action: start) {
                Text(
                    "reading.help.start",
                    comment: "Button that closes the reading instructions and starts practice."
                )
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(EdgeInsets(top: 32, leading: 24, bottom: 32, trailing: 24))
        .frame(
            minWidth: usesTabletPresentation ? 400 : nil,
            maxWidth: usesTabletPresentation ? 400 : .infinity
        )
    }
}

private struct ReadingPracticePausedView: View {
    let resume: () -> Void
    let quit: () -> Void

    var body: some View {
        VStack(spacing: 40) {
            Text(
                "reading.paused.title",
                comment: "Message shown when reading practice was interrupted by leaving the app."
            )
            .font(.title.weight(.semibold))
            .multilineTextAlignment(.center)

            VStack(spacing: 16) {
                AppButton(style: .filled, size: .large, action: resume) {
                    Text(
                        "reading.paused.resume",
                        comment: "Button that restarts the interrupted reading card with a full timer."
                    )
                }

                AppButton(style: .muted, size: .medium, action: quit) {
                    Text(
                        "reading.paused.quit",
                        comment: "Button that exits an interrupted reading practice session."
                    )
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground).opacity(0.82).ignoresSafeArea())
    }
}

private struct ReadingPracticeCompletionView: View {
    let score: Double
    let messageKey: LocalizedStringKey
    let practiseAgain: () -> Void

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                VStack(spacing: 32) {
                    Spacer()

                    Text(messageKey)
                        .font(.title2.weight(.semibold))
                        .multilineTextAlignment(.center)

                    PracticeScoreBar(score: score)
                        .frame(maxWidth: 440)

                    Spacer()
                }
                .frame(height: geometry.size.height / 2)

                VStack(spacing: 24) {
                    Spacer()

                    HStack(spacing: 8) {
                        Text(
                            "reading.completion.practice_score",
                            comment: "Label before the reading practice score circles."
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                        MasteryIndicator(
                            value: min(score, 5),
                            shape: .circle,
                            showsBlitz: score >= ProgressPolicy.blitzThreshold
                        )
                    }

                    AppButton(style: .filled, size: .medium, action: practiseAgain) {
                        Text(
                            "activity.action.practise_again",
                            comment: "Button that repeats the same reading practice items in a new order."
                        )
                    }

                    Spacer()
                }
                .frame(height: geometry.size.height / 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 24)
        }
    }
}

private extension Duration {
    var timeInterval: TimeInterval {
        let components = self.components
        return TimeInterval(components.seconds)
            + TimeInterval(components.attoseconds) / 1_000_000_000_000_000_000
    }
}

#Preview("Reading practice") {
    @Previewable @State var progress = UserProgress()

    let locale = Locale(identifier: "en_AU")
    let level = MockCourse.course(locale: locale).levels[0]

    NavigationStack {
        ReadingPracticeView(
            levelID: level.id,
            activity: level.currentActivities[1],
            progress: $progress
        )
    }
    .environment(\.locale, locale)
}

#Preview("Reading practice – Paused overlay") {
    let locale = Locale(identifier: "en_AU")

    PracticeSessionShell(
        title: String(
            localized: "activity.reading.title",
            defaultValue: "Reading Practice",
            locale: locale
        ),
        background: Color(.systemGroupedBackground),
        close: {}
    ) {
        VStack(spacing: 32) {
            PracticeProgressBar(value: 0.35)
                .padding(.horizontal)

            RoundedRectangle(cornerRadius: 32)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay {
                    Text(verbatim: "아")
                        .font(.system(size: 160))
                }
                .frame(maxWidth: 480, maxHeight: 672)
                .aspectRatio(PracticeLayout.flashCardAspectRatio, contentMode: .fit)
                .padding(.horizontal)

            AppButton(style: .filled, size: .large, width: .fill, action: {}) {
                Text(
                    "reading.action.check_answer",
                    comment: "Button that stops the reading timer and reveals the answer."
                )
            }
            .padding(.horizontal)
        }
        .blur(radius: 12)
    }
    .overlay {
        ReadingPracticePausedView(resume: {}, quit: {})
    }
    .environment(\.locale, locale)
}

#Preview("Reading practice – Complete") {
    let locale = Locale(identifier: "en_AU")

    PracticeSessionShell(
        title: String(
            localized: "activity.reading.title",
            defaultValue: "Reading Practice",
            locale: locale
        ),
        background: Color(.systemBackground),
        close: {}
    ) {
        ReadingPracticeCompletionView(
            score: 4.4,
            messageKey: "reading.completion.nice_progress",
            practiseAgain: {}
        )
    }
    .environment(\.locale, locale)
}
