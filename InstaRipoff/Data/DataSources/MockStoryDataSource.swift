//
//  MockStoryDataSource.swift
//  InstaRipoff
//
//  Created on 23/10/2025.
//

import Foundation

class MockStoryDataSource: StoryDataSource {
    func fetchUsers() async throws -> [User] {
        // Minimal delay for realism
        try await Task.sleep(nanoseconds: 50_000_000) // 0.05s
        
        guard let url = Bundle.main.url(forResource: "users", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return []
        }
        
        let decoder = JSONDecoder()
        let response = try decoder.decode(UserResponse.self, from: data)
        return response.pages.flatMap { $0.users }
    }
    
    func fetchStories(for userId: Int) async throws -> [Story] {
        // Minimal delay for realism
        try await Task.sleep(nanoseconds: 50_000_000) // 0.05s
        
        // Get stories from persistent storage
        let stories = await StoryStorage.shared.getStories(for: userId)
        print("📖 Fetching stories for user \(userId): \(stories.count) stories")
        return stories
    }
}
