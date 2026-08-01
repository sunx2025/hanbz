//
//  ActivityCard.swift
//  hangulblitz
//

import SwiftUI

struct ActivityCard: View {
    let activity: LearningActivity
    let presentation: Presentation
    let action: () -> Void

    private var progress: ActivityDisplayProgress? {
        MockProgress.activity(activity.id)
    }

    // Card layout is different between narrower and wider screens
    enum Presentation {
        case listRow // show as list items on narrower screens
        case gridCard // show as larger card items on wider screens
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            VStack(alignment: .leading, spacing: presentation == .gridCard ? 8 : 4) {
                Text(verbatim: activity.title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(verbatim: activity.description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)

                status

                if presentation == .gridCard {
                    callToActionButton
                }
            }
            .frame(maxWidth: .infinity, minHeight: presentation == .gridCard ? 128 : nil, alignment: .topLeading)
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(.rect(cornerRadius: 16))

            if presentation == .listRow {
                Button(action: action) {
                    Color.clear
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: activity.title))
            }
        }
    }

    @ViewBuilder
    private var status: some View {
        if let score = progress?.score {
            MasteryIndicator(value: score)
        } else if presentation == .listRow, progress?.isCompleted == true {
            Label {
                Text("activity.status.done", comment: "Status shown when a non-scored activity has been completed.")
            } icon: {
                Image(systemName: "checkmark.circle.fill")
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.tint)
        }
    }

    private var callToActionKey: LocalizedStringKey {
        progress?.hasAttempt == true ? "activity.action.practise_again" : "activity.action.start"
    }

    private var callToActionComment: StaticString {
        progress?.hasAttempt == true
            ? "Button that starts an activity the user has attempted before."
            : "Button that starts an activity for the first time."
    }

    private var callToActionButton: some View {
        AppButton(
            style: progress?.hasAttempt == true ? .outlined : .filled,
            size: .small,
            action: action
        ) {
            Text(callToActionKey, comment: callToActionComment)
        }
    }
}

#Preview("Activity card states") {
    let locale = Locale(identifier: "en_AU")
    let course = MockCourse.course(locale: locale)
    let completed = course.levels[0].currentActivities[0]
    let scored = course.levels[0].currentActivities[1]
    let notStarted = course.levels[1].currentActivities[0]

    ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            Text("Without call to action")
                .font(.headline)

            ActivityCard(activity: completed, presentation: .listRow) {}
            ActivityCard(activity: scored, presentation: .listRow) {}
            ActivityCard(activity: notStarted, presentation: .listRow) {}

            Text("With call to action")
                .font(.headline)
                .padding(.top, 8)

            ActivityCard(activity: notStarted, presentation: .gridCard) {}
            ActivityCard(activity: scored, presentation: .gridCard) {}
        }
        .padding(16)
    }
    .background(Color(.systemGroupedBackground))
    .environment(\.locale, locale)
}
