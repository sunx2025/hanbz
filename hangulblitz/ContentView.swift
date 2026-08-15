//
//  ContentView.swift
//  hangulblitz
//
//  Created by Sun Xie on 29/7/2026.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.locale) private var locale
    @State private var selectedLevelID: String?
    @State private var preferredCompactColumn = NavigationSplitViewColumn.sidebar
    @State private var presentedActivity: PresentedActivity?
    @State private var progress = UserProgress.load()

    var body: some View {
        let course = MockCourse.course(locale: locale)

        TabletHomeView(
            course: course,
            progress: progress,
            selectedLevelID: $selectedLevelID,
            preferredCompactColumn: $preferredCompactColumn,
            onPresentActivity: { levelID, activity in
                presentedActivity = PresentedActivity(
                    levelID: levelID,
                    activity: activity
                )
            }
        ) {
            appMenu
        }
        .fullScreenCover(item: $presentedActivity) { presentedActivity in
            NavigationStack {
                activityView(for: presentedActivity, in: course)
            }
        }
        .tint(.accentColor)
    }

    private var appMenu: some View {
        Menu {
            Button(action: { /* TODO: Present the feedback flow. */ }) {
                Label {
                    Text("menu.send_feedback", comment: "Menu action that lets the user send feedback about the app.")
                } icon: {
                    Image(systemName: "bubble.left.and.bubble.right")
                }
            }

            Button(action: { /* TODO: Present frequently asked questions. */ }) {
                Label {
                    Text("menu.faq", comment: "Menu action that opens frequently asked questions.")
                } icon: {
                    Image(systemName: "questionmark.folder")
                }
            }

            Button(action: { /* TODO: Open the App Store rating flow. */ }) {
                Label {
                    Text("menu.rate_app", comment: "Menu action that asks the user to rate the app.")
                } icon: {
                    Image(systemName: "heart")
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal")
        }
        .accessibilityLabel(
            Text("menu.accessibility_label", comment: "Accessibility label for the main app menu button.")
        )
    }

    @ViewBuilder
    private func activityView(
        for presentedActivity: PresentedActivity,
        in course: Course
    ) -> some View {
        switch presentedActivity.activity.kind {
        case .guided:
            let readingActivity = course
                .level(id: presentedActivity.levelID)?
                .currentActivities
                .first { $0.kind == .reading }

            GuidedPracticeView(
                levelID: presentedActivity.levelID,
                activity: presentedActivity.activity,
                readingActivity: readingActivity,
                progress: $progress
            )

        case .reading:
            ReadingPracticeView(
                levelID: presentedActivity.levelID,
                activity: presentedActivity.activity,
                progress: $progress
            )

        case .listening:
            ActivityPlaceholderView(
                title: presentedActivity.activity.title,
                showsCloseButton: true
            )
        }
    }

    private struct PresentedActivity: Identifiable {
        let levelID: String
        let activity: LearningActivity

        var id: String {
            "\(levelID)-\(activity.id)"
        }
    }
}

#Preview("iPhone – English") {
    ContentView()
        .environment(\.locale, Locale(identifier: "en_AU"))
}

#Preview("iPhone – 简体中文") {
    ContentView()
        .environment(\.locale, Locale(identifier: "zh_Hans"))
}

#Preview("iPad – Portrait") {
    ContentView()
        .environment(\.locale, Locale(identifier: "en_AU"))
        .environment(\.horizontalSizeClass, .regular)
        .frame(width: 834, height: 1_194)
}

#Preview("iPad – Landscape") {
    ContentView()
        .environment(\.locale, Locale(identifier: "en_AU"))
        .environment(\.horizontalSizeClass, .regular)
        .frame(width: 1_194, height: 834)
}
