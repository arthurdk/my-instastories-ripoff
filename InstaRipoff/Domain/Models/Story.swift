//
//  Story.swift
//  InstaRipoff
//
//  Created on 23/10/2025.
//

import Foundation

struct Story: Identifiable, Equatable {
    let id: UUID
    let userId: Int
    let imageUrl: String
    let timestamp: Date
    var viewedBy: Set<Int> // Track which users have viewed this story - only fine for a prototype
    var reaction: ReactionType?
    var replies: [Reply]
    var viewerIds: [Int]
    var caption: String?
    
    var viewCount: Int { viewerIds.count }
    
    // Helper to check if a specific user has viewed this story
    func isViewed(by viewerId: Int) -> Bool {
        return viewedBy.contains(viewerId)
    }
    
    // Helper to mark as viewed by a specific user
    mutating func markAsViewed(by viewerId: Int) {
        viewedBy.insert(viewerId)
    }
    
    var timeAgo: String {
        let interval = Date().timeIntervalSince(timestamp)
        let minutes = Int(interval / 60)
        
        if minutes < 1 { return "now" }
        if minutes < 60 { return "\(minutes)m" }
        
        let hours = Int(interval / 3600)
        if hours < 24 { return "\(hours)h" }
        
        let days = hours / 24
        return "\(days)d"
    }
}
