//
//  TabletHomeView.swift
//  hangulblitz
//

import SwiftUI

struct TabletHomeView<SidebarMenu: View>: View {
    let course: Course
    @Binding var selectedLevelID: String?
    @Binding var preferredCompactColumn: NavigationSplitViewColumn
    let onPresentActivity: (String, LearningActivity) -> Void
    let sidebarMenu: SidebarMenu

    @Environment(\.locale) private var locale
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var detailPath: [AppRoute] = []

    init(
        course: Course,
        selectedLevelID: Binding<String?>,
        preferredCompactColumn: Binding<NavigationSplitViewColumn>,
        onPresentActivity: @escaping (String, LearningActivity) -> Void,
        @ViewBuilder sidebarMenu: () -> SidebarMenu
    ) {
        self.course = course
        _selectedLevelID = selectedLevelID
        _preferredCompactColumn = preferredCompactColumn
        self.onPresentActivity = onPresentActivity
        self.sidebarMenu = sidebarMenu()
    }

    private var selectedLevel: Level? {
        selectedLevelID.flatMap(course.level(id:)) ?? course.levels.first
    }

    var body: some View {
        NavigationSplitView(preferredCompactColumn: $preferredCompactColumn) {
            LevelListView(
                levels: course.levels,
                selectedLevelID: $selectedLevelID,
                usesCardRows: horizontalSizeClass == .compact
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    sidebarMenu
                }

                ToolbarItem(placement: .principal) {
                    BrandLogo()
                        .allowsHitTesting(false)
                }
            }
        } detail: {
            NavigationStack(path: $detailPath) {
                if let selectedLevel {
                    LevelActivitiesView(
                        level: selectedLevel,
                        onOpenRoute: open
                    )
                    .id(selectedLevel.id)
                    .navigationDestination(for: AppRoute.self) { route in
                        destination(for: route)
                    }
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onChange(of: selectedLevelID) {
            detailPath.removeAll()
        }
        .onAppear {
            selectInitialLevelWhenExpanded()
        }
        .onChange(of: horizontalSizeClass) {
            selectInitialLevelWhenExpanded()
        }
    }

    private func open(_ route: AppRoute) {
        switch route {
        case let .level(levelID):
            selectedLevelID = levelID

        case .overview:
            detailPath.append(route)

        case let .activity(levelID, activityID):
            guard let activity = course.level(id: levelID)?.activity(id: activityID) else {
                return
            }
            onPresentActivity(levelID, activity)
        }
    }

    private func selectInitialLevelWhenExpanded() {
        guard horizontalSizeClass == .regular, selectedLevelID == nil else {
            return
        }
        selectedLevelID = course.levels.first?.id
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .overview:
            ActivityPlaceholderView(
                title: String(
                    localized: "activity.overview.title",
                    defaultValue: "Overview",
                    locale: locale,
                    comment: "Title of the level overview activity."
                )
            )

        case .level, .activity:
            EmptyView()
        }
    }
}
