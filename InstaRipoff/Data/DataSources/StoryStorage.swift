//
//  StoryStorage.swift
//  InstaRipoff
//
//  Created on 23/10/2025.
//

import Foundation

@MainActor
class StoryStorage: ObservableObject {
    static let shared = StoryStorage()
    
    @Published var allStories: [Int: [Story]] = [:] // userId -> stories
    
    private let storageKey = "persistedStories"
    private let defaults = UserDefaults.standard
    
    // Fixed set of VERIFIED image URLs
    private let reliableImageUrls = [
        "https://picsum.photos/id/1/400/600",
        "https://picsum.photos/id/10/400/600",
        "https://picsum.photos/id/100/400/600",
        "https://picsum.photos/id/1011/400/600",
        "https://picsum.photos/id/1015/400/600",
        "https://picsum.photos/id/1016/400/600",
        "https://picsum.photos/id/1018/400/600",
        "https://picsum.photos/id/1019/400/600",
        "https://picsum.photos/id/1025/400/600",
        "https://picsum.photos/id/103/400/600",
        "https://picsum.photos/id/1035/400/600",
        "https://picsum.photos/id/104/400/600",
        "https://picsum.photos/id/1043/400/600",
        "https://picsum.photos/id/106/400/600",
        "https://picsum.photos/id/1062/400/600",
        "https://picsum.photos/id/107/400/600",
        "https://picsum.photos/id/108/400/600",
        "https://picsum.photos/id/109/400/600",
        "https://picsum.photos/id/110/400/600",
        "https://picsum.photos/id/111/400/600",
        "https://picsum.photos/id/112/400/600",
        "https://picsum.photos/id/113/400/600",
        "https://picsum.photos/id/116/400/600",
        "https://picsum.photos/id/117/400/600",
        "https://picsum.photos/id/12/400/600",
        "https://picsum.photos/id/120/400/600",
        "https://picsum.photos/id/121/400/600",
        "https://picsum.photos/id/122/400/600",
        "https://picsum.photos/id/123/400/600",
        "https://picsum.photos/id/124/400/600",
        "https://picsum.photos/id/125/400/600",
        "https://picsum.photos/id/128/400/600",
        "https://picsum.photos/id/13/400/600",
        "https://picsum.photos/id/130/400/600",
        "https://picsum.photos/id/133/400/600",
        "https://picsum.photos/id/134/400/600",
        "https://picsum.photos/id/137/400/600",
        "https://picsum.photos/id/14/400/600",
        "https://picsum.photos/id/15/400/600",
        "https://picsum.photos/id/16/400/600",
    ]
    
    // Sample captions for random generation
    private let sampleCaptions = [
        "Living my best life 🌟",
        "Good vibes only ✨",
        "Making memories 📸",
        "Adventure awaits! 🌍",
        "Blessed and grateful 🙏",
        "Chasing dreams 💫",
        "Sunset lover 🌅",
        "Coffee first ☕️",
        "Weekend mood 🎉",
        "Simple pleasures 💕",
        "Just another day in paradise 🏝",
        "Feeling good 😊",
        "Can't stop won't stop 💪",
        "New day, new opportunities",
        "Throwback to better times",
        "Living for the moments",
        "Sky above, earth below, peace within",
        "Good times and tan lines",
        "Smile big, laugh often",
        nil, nil, nil  // Some stories without captions
    ]
    
    private init() {
        loadStories()
    }
    
    // MARK: - Persistence
    
    private func loadStories() {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Int: [StoryCodable]].self, from: data) else {
            // Initialize with default stories if none exist
            initializeDefaultStories()
            return
        }
        
        // Convert StoryCodable to Story
        allStories = decoded.mapValues { codableStories in
            codableStories.map { $0.toStory() }
        }
    }
    
    private func saveStories() {
        // Convert Story to StoryCodable
        let codableStories = allStories.mapValues { stories in
            stories.map { StoryCodable(from: $0) }
        }
        
        if let encoded = try? JSONEncoder().encode(codableStories) {
            defaults.set(encoded, forKey: storageKey)
        }
    }
    
    // MARK: - Story Management
    
    func getStories(for userId: Int) async -> [Story] {
        return allStories[userId] ?? []
    }
    
    func addStory(_ story: Story, for userId: Int) {
        if allStories[userId] == nil {
            allStories[userId] = []
        }
        allStories[userId]?.insert(story, at: 0) // Add to beginning
        print("➕ Added story for user \(userId). Total stories: \(allStories[userId]?.count ?? 0)")
        print("   Image: \(story.imageUrl.prefix(50))...")
        print("   Timestamp: \(story.timestamp)")
        saveStories()
    }
    
    func updateStory(_ story: Story, for userId: Int) {
        guard var userStories = allStories[userId],
              let index = userStories.firstIndex(where: { $0.id == story.id }) else {
            return
        }
        userStories[index] = story
        allStories[userId] = userStories
        saveStories()
    }
    
    func addRandomNewStories() -> Bool {
        // Always add new stories for pull-to-refresh feature
        
        // Select 1-3 random users to add stories to
        let availableUserIds = Array(allStories.keys)
        if availableUserIds.isEmpty {
            print("⚠️ No users available to add stories")
            return false
        }
        
        let numberOfUsers = Int.random(in: 1...min(3, availableUserIds.count))
        let selectedUsers = availableUserIds.shuffled().prefix(numberOfUsers)
        
        print("📝 Adding new stories to \(numberOfUsers) users: \(Array(selectedUsers))")
        
        for userId in selectedUsers {
            // Get existing stories to check timestamps
            let existingStories = allStories[userId] ?? []
            let existingMostRecent = existingStories.first?.timestamp ?? .distantPast
            
            // Use a reliable image from our fixed set
            let imageUrl = reliableImageUrls.randomElement() ?? reliableImageUrls[0]
            let randomCaption = sampleCaptions.randomElement() ?? nil
            let newTimestamp = Date()
            
            let newStory = Story(
                id: UUID(),
                userId: userId,
                imageUrl: imageUrl,
                timestamp: newTimestamp,
                viewedBy: [],  // New story is unread by anyone
                reaction: nil,
                replies: [],
                viewerIds: generateRandomViewers(),
                caption: randomCaption
            )
            
            print("  ➕ User \(userId): Adding story")
            print("     Image URL: \(imageUrl)")
            print("     Old most recent: \(existingMostRecent)")
            print("     New timestamp: \(newTimestamp)")
            print("     Is newer: \(newTimestamp > existingMostRecent)")
            addStory(newStory, for: userId)
        }
        
        print("✅ Successfully added \(numberOfUsers) new stories")
        return true
    }
    
    // MARK: - Initial Data
    
    private func initializeDefaultStories() {
        // Pre-populate with sample stories for some users
        // Add stories for ALL users (1-20) for demo
        for userId in 1...20 {
            let storyCount = (userId % 6) + 1 // Deterministic: 1-6 stories per user
            var stories: [Story] = []
            
            for index in 0..<storyCount {
                // Use reliable images from our fixed set (deterministic per user+index)
                let imageIndex = (userId * 7 + index * 3) % reliableImageUrls.count
                let imageUrl = reliableImageUrls[imageIndex]
                let randomCaption = sampleCaptions.randomElement() ?? nil
                
                // All stories start as unseen by anyone
                
                let story = Story(
                    id: UUID(),
                    userId: userId,
                    imageUrl: imageUrl,
                    timestamp: Date().addingTimeInterval(-Double(index * 3600 + (userId * 300))),
                    viewedBy: [],  // No one has viewed yet
                    reaction: nil,
                    replies: [],
                    viewerIds: generateRandomViewers(),
                    caption: randomCaption
                )
                stories.append(story)
            }
            
            allStories[userId] = stories
        }
        
        saveStories()
    }
    
    private func generateRandomViewers() -> [Int] {
        let viewerCount = Int.random(in: 5...25)
        return (1...viewerCount).map { $0 }
    }
    
    func resetToDefaults() {
        print("🔄 Resetting StoryStorage to defaults...")
        defaults.removeObject(forKey: storageKey)
        initializeDefaultStories()
        print("✅ Reset complete - all users now have 1 unseen story")
    }
}

struct StoryCodable: Codable {
    let id: UUID
    let userId: Int
    let imageUrl: String
    let timestamp: Date
    var viewedBy: [Int] // Store as array for Codable compatibility
    var reaction: ReactionType?
    var replies: [ReplyCodable]
    var viewerIds: [Int]
    var caption: String?
    
    init(from story: Story) {
        self.id = story.id
        self.userId = story.userId
        self.imageUrl = story.imageUrl
        self.timestamp = story.timestamp
        self.viewedBy = Array(story.viewedBy) // Convert Set to Array
        self.reaction = story.reaction
        self.replies = story.replies.map { ReplyCodable(from: $0) }
        self.viewerIds = story.viewerIds
        self.caption = story.caption
    }
    
    func toStory() -> Story {
        Story(
            id: id,
            userId: userId,
            imageUrl: imageUrl,
            timestamp: timestamp,
            viewedBy: Set(viewedBy), // Convert Array to Set
            reaction: reaction,
            replies: replies.map { $0.toReply() },
            viewerIds: viewerIds,
            caption: caption
        )
    }
}

struct ReplyCodable: Codable {
    let id: UUID
    let userId: Int
    let text: String
    let timestamp: Date
    
    init(from reply: Reply) {
        self.id = reply.id
        self.userId = reply.userId
        self.text = reply.text
        self.timestamp = reply.timestamp
    }
    
    func toReply() -> Reply {
        Reply(id: id, userId: userId, text: text, timestamp: timestamp)
    }
}
