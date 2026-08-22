//
//  LevelActivitiesView.swift
//  hangulblitz
//

import SwiftUI

struct LevelActivitiesView: View {
    let level: Level
    let progress: UserProgress
    let onOpenRoute: (AppRoute) -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.locale) private var locale

    var body: some View {
        GeometryReader { geometry in
            LevelActivitiesContent(
                level: level,
                progress: progress,
                columnCount: columnCount(for: geometry.size.width),
                //showsLevelHeading: false,
                activityCardPresentation: horizontalSizeClass == .compact ? .listRow : .gridCard,
                onOpenRoute: onOpenRoute
            )
        }
        .navigationTitle(level.displayTitle(locale: locale))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func columnCount(for availableWidth: CGFloat) -> Int {
        guard horizontalSizeClass != .compact else { return 1 }

        let minimumCardWidth: CGFloat = 260
        let spacing: CGFloat = 16
        let fittingCount = Int((availableWidth + spacing) / (minimumCardWidth + spacing))
        return min(max(fittingCount, 2), 3)
    }
}

struct LevelActivitiesContent: View {
    let level: Level
    let progress: UserProgress
    let columnCount: Int
    //let showsLevelHeading: Bool
    let activityCardPresentation: ActivityCard.Presentation
    let onOpenRoute: (AppRoute) -> Void

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: 16, alignment: .top),
            count: columnCount
        )
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
//                if showsLevelHeading {
//                    LevelTitle(level: level)
//                        .font(.title3.weight(.semibold))
//                }

                if level.overview != nil {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                        OverviewCard(cardPresentation: activityCardPresentation) {
                            onOpenRoute(.overview(level.id))
                        }
                    }
                }

                sectionTitle(
                    key: "section.current_level",
                    comment: "Heading above activities that focus on the selected level."
                )

                activityGrid(level.currentActivities)

                sectionTitle(
                    key: "section.mixed_review",
                    comment: "Heading above activities that review the selected and earlier levels together."
                )

                activityGrid(level.mixedActivities)
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func activityGrid(_ activities: [LearningActivity]) -> some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
            ForEach(activities) { activity in
                ActivityCard(
                    activity: activity,
                    presentation: activityCardPresentation,
                    progress: displayProgress(for: activity)
                ) {
                    onOpenRoute(.activity(levelID: level.id, activityID: activity.id))
                }
            }
        }
    }

    private func displayProgress(for activity: LearningActivity) -> ActivityDisplayProgress? {
        let state = progress.levels[level.id] ?? LevelLearningState()
        let activityProgress = ActivityProgress(
            activity: activity,
            levelID: level.id,
            state: state
        )

        guard activityProgress.hasAttempt else { return nil }
        return ActivityDisplayProgress(
            hasAttempt: true,
            isCompleted: activityProgress.isCompleted,
            score: activityProgress.mastery
        )
    }

    private func sectionTitle(key: LocalizedStringKey, comment: StaticString) -> some View {
        Text(key, comment: comment)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.top, 4)
    }
}

private struct OverviewCard: View {
    let cardPresentation: ActivityCard.Presentation
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(.rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            Text("activity.overview.title", comment: "Title of the level overview activity.")
        )
    }

    @ViewBuilder
    private var content: some View {
        switch cardPresentation {
        case .listRow:
            HStack(alignment: .center, spacing: 8) {
                ActivityLeadingIcon(systemName: "book.fill")
                title
            }
        case .gridCard:
            VStack(alignment: .leading, spacing: 8) {
                title

                HStack(spacing: 4) {
                    Text("activity.overview.action.read", comment: "Action text shown on the overview card on wider layouts.")

                    Image(systemName: "chevron.right")
                        .imageScale(.small)
                }
                .font(.headline)
                .foregroundStyle(.tint)
            }
        }
    }

    private var title: some View {
        Text("activity.overview.title", comment: "Title of the level overview activity.")
            .font(.headline)
            .foregroundStyle(.primary)
    }
}

#Preview("Level activities") {
    let locale = Locale(identifier: "en_AU")

    NavigationStack {
        LevelActivitiesView(
            level: MockCourse.course(locale: locale).levels[0],
            progress: UserProgress(),
            onOpenRoute: { _ in }
        )
    }
    .environment(\.locale, locale)
}
