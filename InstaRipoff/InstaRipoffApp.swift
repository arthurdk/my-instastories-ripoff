//
//  InstaRipoffApp.swift
//  InstaRipoff
//
//  Created by Arthur De Kimpe on 23/10/2025.
//

import SwiftUI

@main
struct InstaRipoffApp: App {
    @StateObject private var authManager = AuthManager()
    
    init() {
        // Clear all data on each app launch (simulate reinstall)
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
    }
    
    var body: some Scene {
        WindowGroup {
            if authManager.isAuthenticated {
                StoryListView()
                    .environmentObject(authManager)
            } else {
                LoginView()
                    .environmentObject(authManager)
            }
        }
    }
}
