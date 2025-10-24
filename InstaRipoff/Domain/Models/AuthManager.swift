//
//  AuthManager.swift
//  InstaRipoff
//
//  Created on 23/10/2025.
//

import Foundation

@MainActor
class AuthManager: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: User?
    
    func login(username: String, password: String) async {
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        guard let url = Bundle.main.url(forResource: "users", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return
        }
        
        let decoder = JSONDecoder()
        
        guard let response = try? decoder.decode(UserResponse.self, from: data) else {
            return
        }
        
        let allUsers = response.pages.flatMap { $0.users }
        
        // Check if username matches any user name (case-insensitive)
        if let matchedUser = allUsers.first(where: { $0.name.lowercased() == username.lowercased() }) {
            currentUser = matchedUser
        } else {
            // Use stable hash for random but consistent assignment
            let usernameHash = stableHash(for: username)
            let userIndex = usernameHash % allUsers.count
            currentUser = allUsers[userIndex]
        }
        
        isAuthenticated = true
    }
    
    private func stableHash(for string: String) -> Int {
        var hash = 5381
        for char in string.utf8 {
            hash = ((hash << 5) &+ hash) &+ Int(char)
        }
        return abs(hash)
    }
    
    func logout() {
        isAuthenticated = false
        currentUser = nil
    }
}
