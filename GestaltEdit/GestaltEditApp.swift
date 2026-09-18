//
//  GestaltEditApp.swift
//  GestaltEdit
//

import SwiftUI

@main
struct GestaltEditApp: App {
    @StateObject private var viewModel = GestaltViewModel()

    init() {
        if GestaltAccess.isBuildConfigurationSafe() {
            AutomationCommand.runIfNeeded()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
    }
}
