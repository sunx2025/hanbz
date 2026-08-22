//
//  TabletHomeView.swift
//  hangulblitz
//

import SwiftUI

struct TabletHomeView<SidebarMenu: View>: View {
    let course: Course
    let progress: UserProgress
    @Binding var selectedLevelID: String?
    @Binding var preferredCompactColumn: NavigationSplitViewColumn
    let onPresentActivity: (String, LearningActivity) -> Void
    let sidebarMenu: SidebarMenu

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var columnVisibility = NavigationSplitViewVisibility.automatic
    @State private var detailPath: [AppRoute] = []

    init(
        course: Course,
        progress: UserProgress,
        selectedLevelID: Binding<String?>,
        preferredCompactColumn: Binding<NavigationSplitViewColumn>,
        onPresentActivity: @escaping (String, LearningActivity) -> Void,
        @ViewBuilder sidebarMenu: () -> SidebarMenu
    ) {
        self.course = course
        self.progress = progress
        _selectedLevelID = selectedLevelID
        _preferredCompactColumn = preferredCompactColumn
        self.onPresentActivity = onPresentActivity
        self.sidebarMenu = sidebarMenu()
    }

    private var selectedLevel: Level? {
        selectedLevelID.flatMap(course.level(id:)) ?? course.levels.first
    }

    var body: some View {
        NavigationSplitView(
            columnVisibility: $columnVisibility,
            preferredCompactColumn: $preferredCompactColumn
        ) {
            LevelListView(
                levels: course.levels,
                progress: progress,
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
                        progress: progress,
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
            restoreAllColumns()
        }
        .onChange(of: detailPath) {
            if detailPath.isEmpty {
                restoreAllColumns()
            }
        }
        .onAppear {
            selectInitialLevelWhenExpanded()
        }
        .onChange(of: horizontalSizeClass) {
            selectInitialLevelWhenExpanded()
            if horizontalSizeClass == .regular {
                columnVisibility = detailPath.isEmpty ? .all : .detailOnly
            }
        }
    }

    private func open(_ route: AppRoute) {
        switch route {
        case let .level(levelID):
            selectedLevelID = levelID

        case .overview:
            detailPath.append(route)
            if horizontalSizeClass == .regular {
                columnVisibility = .detailOnly
            }

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

    private func restoreAllColumns() {
        if horizontalSizeClass == .regular {
            columnVisibility = .all
        }
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case let .overview(levelID):
            if let level = course.level(id: levelID) {
                OverviewView(level: level)
            }

        case .level, .activity:
            EmptyView()
        }
    }

}
