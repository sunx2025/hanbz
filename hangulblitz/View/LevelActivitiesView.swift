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
#if DEBUG
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                // Comment out this NavigationLink to hide the temporary debug entry.
//                NavigationLink {
//                    LevelProgressDebugView(level: level, progress: progress)
//                } label: {
//                    Image(systemName: "doc.badge.gearshape")
//                }
//                .accessibilityLabel("Open level progress debug view")
            }
        }
#endif
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

                if !level.currentActivities.isEmpty {
                    sectionTitle(
                        key: "section.current_level",
                        comment: "Heading above activities that focus on the selected level."
                    )

                    activityGrid(level.currentActivities)
                }

                if !level.mixedActivities.isEmpty {
                    sectionTitle(
                        key: "section.mixed_review",
                        comment: "Heading above activities that review the selected and earlier levels together."
                    )

                    activityGrid(level.mixedActivities)
                }

                if level.apply != nil {
                    sectionTitle(
                        key: "section.extension",
                        comment: "Heading above optional extension reading for a level."
                    )

                    LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                        ApplyCard(cardPresentation: activityCardPresentation) {
                            onOpenRoute(.apply(level.id))
                        }
                    }
                }
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
        ActivityDisplayProgress(
            activity: activity,
            levelID: level.id,
            userProgress: progress
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
        CourseContentCard(
            title: Text(
                "activity.overview.title",
                comment: "Title of the level overview activity."
            ),
            subtitle: nil,
            systemImage: "book.fill",
            presentation: cardPresentation,
            action: action
        )
    }
}

private struct ApplyCard: View {
    let cardPresentation: ActivityCard.Presentation
    let action: () -> Void

    var body: some View {
        CourseContentCard(
            title: Text(
                "activity.apply.title",
                comment: "Title of the optional words and phrases article."
            ),
            subtitle: Text(
                "activity.apply.description",
                comment: "Subtitle of the optional words and phrases article."
            ),
            systemImage: "sparkles",
            presentation: cardPresentation,
            action: action
        )
    }
}

private struct CourseContentCard: View {
    let title: Text
    let subtitle: Text?
    let systemImage: String
    let presentation: ActivityCard.Presentation
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                switch presentation {
                case .listRow:
                    HStack(alignment: .center, spacing: 8) {
                        ActivityLeadingIcon(systemName: systemImage)
                        labels
                    }
                case .gridCard:
                    VStack(alignment: .leading, spacing: 8) {
                        labels

                        HStack(spacing: 4) {
                            Text(
                                "activity.overview.action.read",
                                comment: "Action text shown on article cards on wider layouts."
                            )

                            Image(systemName: "chevron.right")
                                .imageScale(.small)
                        }
                        .font(.headline)
                        .foregroundStyle(.tint)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(.rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private var labels: some View {
        VStack(alignment: .leading, spacing: 4) {
            title
                .font(.headline)
                .foregroundStyle(.primary)

            if let subtitle {
                subtitle
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
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
