//
//  AppRoute.swift
//  hangulblitz
//

import Foundation

enum AppRoute: Hashable {
    case level(String)
    case overview(String)
    case activity(levelID: String, activityID: String)
}
