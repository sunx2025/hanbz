//
//  ListeningPracticeView.swift
//  hangulblitz
//

import SwiftUI

struct ListeningPracticeView: View {
    let levelID: String
    let activity: LearningActivity

    @Binding private var progress: UserProgress

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase

    @State private var session: ListeningPracticeSession
    @State private var audioPlayer = PracticeAudioPlayer()
    @State private var feedbackPlayer = FeedbackAudioPlayer()
    @State private var hasAppeared = false
    @State private var readyLightCount = 0
    @State private var cardStartedAt: ContinuousClock.Instant?
    @State private var currentAudioIsScorable = true
    @State private var readyTask: Task<Void, Never>?
    @State private var timerTask: Task<Void, Never>?
    @State private var feedbackTask: Task<Void, Never>?
    @State private var showsHelp = false
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
            initialValue: ListeningPracticeSession(
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
                ListeningPracticePausedView(
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
            let help = ListeningPracticeHelpView(
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
                ListeningPracticeGetReadyView(
                    activeLightCount: readyLightCount,
                    showHelp: openHelp
                )
            case .completed:
                ListeningPracticeCompletionView(
                    score: session.practiceScore,
                    messageKey: completionMessageKey,
                    practiseAgain: restart
                )
            case .prompting, .answering, .feedback, .awaitingContinue:
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
                ListeningFlashCard(
                    item: currentItem,
                    phase: session.phase,
                    remainingFraction: session.remainingFraction,
                    timeout: session.timeout,
                    audioPlayer: audioPlayer,
                    select: select,
                    replay: replayPrompt
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
        case .prompting:
            AppButton(style: .outlined, size: .large, action: {}) {
                Text(
                    "listening.action.not_sure",
                    comment: "Button used when the learner cannot identify a listening item."
                )
            }
            .disabled(true)

        case .answering:
            AppButton(style: .outlined, size: .large, action: chooseNotSure) {
                Text(
                    "listening.action.not_sure",
                    comment: "Button used when the learner cannot identify a listening item."
                )
            }

        case .feedback:
            AppButton(style: .outlined, size: .large, action: {}) {
                Text(
                    "listening.action.not_sure",
                    comment: "Button used when the learner cannot identify a listening item."
                )
            }
            .disabled(true)

        case .awaitingContinue:
            AppButton(style: .filled, size: .large, action: continueAfterTimeout) {
                Text(
                    "listening.action.continue",
                    comment: "Button that advances after a timed-out listening card."
                )
            }

        default:
            EmptyView()
        }
    }

    private var completionMessageKey: LocalizedStringKey {
        if session.hasImproved == true {
            return "listening.completion.faster"
        }

        switch session.practiceScore {
        case ProgressPolicy.blitzThreshold...:
            return "listening.completion.great_consistency"
        case 4...:
            return "listening.completion.nice_progress"
        case 2...:
            return "listening.completion.keep_it_up"
        default:
            return "listening.completion.keep_practising"
        }
    }

    private func startOnce() {
        guard !hasAppeared else { return }
        hasAppeared = true
        beginGetReady()
    }

    private func beginGetReady() {
        stopTransientWork()
        session.beginGetReady()
        readyLightCount = 0

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
            beginPrompt()
        }
    }

    private func beginPrompt() {
        stopCardWork()
        guard let currentItem = session.currentItem else { return }

        currentAudioIsScorable = true
        session.beginCurrentItem()
        audioPlayer.play(text: currentItem.text) {
            if audioPlayer.audioIssue != nil {
                currentAudioIsScorable = false
            }
            guard session.phase == .prompting else { return }
            session.promptFinished()
            beginTimer()
        }
    }

    private func beginTimer() {
        cancelTimer()
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

    private func select(_ option: String) {
        guard canAcceptOption else { return }

        let responseTime = cardStartedAt.map {
            $0.duration(to: ContinuousClock.now).timeInterval
        } ?? 0

        cancelTimer()
        guard let currentItem = session.currentItem else { return }
        let isCorrect = option == currentItem.text
        let submission = session.select(
            option,
            responseTime: responseTime,
            isScorable: currentAudioIsScorable
        )
        record(submission)
        feedbackPlayer.play(isCorrect ? .success : .error)
        scheduleFeedbackAdvance(
            after: isCorrect
                ? ProgressPolicy.listeningCorrectFeedbackDuration
                : ProgressPolicy.listeningOtherFeedbackDuration
        )
    }

    private var canAcceptOption: Bool {
        switch session.phase {
        case .answering:
            true
        case .prompting:
            audioPlayer.playbackProgress >= ProgressPolicy.listeningMinimumAnswerProgress
        default:
            false
        }
    }

    private func chooseNotSure() {
        cancelTimer()
        record(session.chooseNotSure(isScorable: currentAudioIsScorable))
        scheduleFeedbackAdvance(after: ProgressPolicy.listeningOtherFeedbackDuration)
    }

    private func handleTimeout() {
        cancelTimer()
        record(session.timeOut(isScorable: currentAudioIsScorable))
        session.feedbackFinished()
    }

    private func scheduleFeedbackAdvance(after duration: TimeInterval) {
        feedbackTask?.cancel()
        feedbackTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(duration))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            feedbackTask = nil
            session.feedbackFinished()
            advanceIfNeeded()
        }
    }

    private func continueAfterTimeout() {
        session.continueAfterTimeout()
        advanceIfNeeded()
    }

    private func replayPrompt() {
        guard let currentItem = session.currentItem else { return }
        audioPlayer.play(text: currentItem.text)
    }

    private func record(_ submission: ListeningPracticeSubmission?) {
        guard let submission else { return }
        progress.record(submission.attempt, levelID: levelID, text: submission.text)
        progress.save()
    }

    private func advanceIfNeeded() {
        stopCardWork()
        if session.phase != .completed {
            beginPrompt()
        }
    }

    private func restart() {
        stopTransientWork()
        session.restart(progress: progress)
        beginGetReady()
    }

    private func openHelp() {
        stopTransientWork()
        session.resetCurrentItemAfterInterruption()
        showsHelp = true
    }

    private func finishHelp() {
        showsHelp = false
        beginGetReady()
    }

    private func handleScenePhase(_ oldPhase: ScenePhase, _ newPhase: ScenePhase) {
        guard newPhase != .active,
              hasAppeared,
              !showsHelp,
              session.phase != .completed,
              session.configurationError == nil else {
            return
        }

        let wasAnswered: Bool
        switch session.phase {
        case .feedback, .awaitingContinue:
            wasAnswered = true
        default:
            wasAnswered = false
        }

        stopTransientWork()
        if wasAnswered {
            session.advanceAnsweredCardAfterInterruption()
        } else {
            session.resetCurrentItemAfterInterruption()
        }
        showsPausedOverlay = true
    }

    private func resumeAfterInterruption() {
        showsPausedOverlay = false
        if session.phase != .completed {
            beginPrompt()
        }
    }

    private func cancelTimer() {
        timerTask?.cancel()
        timerTask = nil
        cardStartedAt = nil
    }

    private func stopCardWork() {
        cancelTimer()
        feedbackTask?.cancel()
        feedbackTask = nil
        audioPlayer.stop()
        feedbackPlayer.stop()
    }

    private func stopTransientWork() {
        readyTask?.cancel()
        readyTask = nil
        stopCardWork()
    }

    private func close() {
        stopTransientWork()
        dismiss()
    }
}

private struct ListeningPracticeGetReadyView: View {
    let activeLightCount: Int
    let showHelp: () -> Void

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    Spacer()

                    Text(
                        "listening.get_ready.instruction",
                        comment: "Instruction shown above the listening practice get-ready lights."
                    )
                    .font(.callout)
                    .multilineTextAlignment(.center)

                    HStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { index in
                            Text(verbatim: index < activeLightCount ? "🔴" : "⚪️")
                        }
                    }
                    .font(.title2)
                    .accessibilityHidden(true)

                    Text(
                        "listening.get_ready.title",
                        comment: "Title shown while the listening practice countdown lights run."
                    )
                    .font(.title)
                    .foregroundStyle(.secondary)

                    Spacer()
                }
                .frame(height: geometry.size.height * 0.76)

                ListeningHowToPlayButton(action: showHelp)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct ListeningFlashCard: View {
    let item: ListeningPracticeItem
    let phase: ListeningPracticePhase
    let remainingFraction: Double
    let timeout: TimeInterval
    let audioPlayer: PracticeAudioPlayer
    let select: (String) -> Void
    let replay: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let rowHeight = geometry.size.height / 9

            VStack(spacing: 0) {
                ZStack {
                    Text(
                        "listening.instruction.listen_and_choose",
                        comment: "Instruction at the top of a listening practice flashcard."
                    )
                    .font(.headline)

                    HStack {
                        CircularCountdownIndicator(
                            remainingFraction: remainingFraction,
                            duration: timeout
                        )
                        .frame(width: 40, height: 40)
                        Spacer()
                    }
                }
                .frame(height: rowHeight)

                AudioPlaybackIndicator(
                    isPlaying: audioPlayer.isPlaying,
                    isLoading: audioPlayer.isLoading,
                    samples: audioPlayer.samples,
                    replay: replay
                )
                .frame(height: rowHeight * 5)

                ListeningOptionsGrid(
                    options: item.options,
                    correctOption: item.text,
                    feedback: feedback,
                    select: select
                )
                .frame(height: rowHeight * 3)
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

    private var feedback: ListeningFeedback? {
        switch phase {
        case let .feedback(feedback): feedback
        case .awaitingContinue: .timedOut
        default: nil
        }
    }
}

private struct ListeningOptionsGrid: View {
    let options: [String]
    let correctOption: String
    let feedback: ListeningFeedback?
    let select: (String) -> Void

    var body: some View {
        VStack(spacing: 8) {
            switch options.count {
            case 1:
                option(options[0])
            case 2:
                HStack(spacing: 8) {
                    option(options[0])
                    option(options[1])
                }
            case 3:
                HStack(spacing: 8) {
                    option(options[0])
                    option(options[1])
                }
                option(options[2])
            default:
                let rows = Array(options.prefix(4)).chunked(into: 2)
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 8) {
                        ForEach(row, id: \.self) { text in
                            option(text)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func option(_ text: String) -> some View {
        AnswerOptionButton(text: text, state: state(for: text)) {
            select(text)
        }
    }

    private func state(for option: String) -> AnswerOptionState {
        guard let feedback else { return .normal }
        if option == correctOption { return .correct }
        if option == feedback.selectedOption { return .incorrect }
        return .disabled
    }
}

private struct ListeningHowToPlayButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                Text(
                    "listening.help.action",
                    comment: "Button that opens instructions for listening practice."
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

private struct ListeningPracticeHelpView: View {
    let usesTabletPresentation: Bool
    let start: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(
                "listening.help.title",
                comment: "Title of the listening practice instruction sheet."
            )
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .center)

            Text(
                "listening.help.goal",
                comment: "Goal explained in the listening practice instruction sheet."
            )
            .font(.body)
            .fixedSize(horizontal: false, vertical: true)

            Text(
                "listening.help.each_card",
                comment: "Heading before the per-card listening practice instructions."
            )
            .font(.body)

            helpStep(
                title: "listening.help.step_one.title",
                body: "listening.help.step_one.body"
            )
            helpStep(
                title: "listening.help.step_two.title",
                body: "listening.help.step_two.body"
            )

            Spacer(minLength: 8)

            AppButton(style: .outlined, size: .medium, action: start) {
                Text(
                    "listening.help.start",
                    comment: "Button that closes the listening instructions and starts practice."
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

    private func helpStep(title: LocalizedStringKey, body: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            Text(body)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct ListeningPracticePausedView: View {
    let resume: () -> Void
    let quit: () -> Void

    var body: some View {
        VStack(spacing: 40) {
            Text(
                "listening.paused.title",
                comment: "Message shown when listening practice was interrupted by leaving the app."
            )
            .font(.title.weight(.semibold))
            .multilineTextAlignment(.center)

            VStack(spacing: 16) {
                AppButton(style: .filled, size: .large, action: resume) {
                    Text(
                        "listening.paused.resume",
                        comment: "Button that restarts the interrupted listening card."
                    )
                }
                AppButton(style: .muted, size: .medium, action: quit) {
                    Text(
                        "listening.paused.quit",
                        comment: "Button that exits an interrupted listening practice session."
                    )
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground).opacity(0.82).ignoresSafeArea())
    }
}

private struct ListeningPracticeCompletionView: View {
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
                            "listening.completion.practice_score",
                            comment: "Label before the listening practice score circles."
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
                            comment: "Button that repeats the same listening practice items in a new order."
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

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
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

#Preview("Listening practice") {
    @Previewable @State var progress = UserProgress()
    let locale = Locale(identifier: "en_AU")
    let level = MockCourse.course(locale: locale).levels[0]

    NavigationStack {
        ListeningPracticeView(
            levelID: level.id,
            activity: level.currentActivities[2],
            progress: $progress
        )
    }
    .environment(\.locale, locale)
}
