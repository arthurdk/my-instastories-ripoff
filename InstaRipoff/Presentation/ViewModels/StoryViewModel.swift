//
//  StoryViewModel.swift
//  InstaRipoff
//
//  Created on 23/10/2025.
//

import Foundation
import SwiftUI

/**
 STORY SEEN/UNSEEN STATUS - BUSINESS RULES DOCUMENTATION
 ========================================================
 As implemented by Instagram standards (Oct 2025)
 
 Rule 1: Individual Story Viewing
 - Each story is marked as "viewed" when its image loads AND it becomes the currently visible story
 - This happens in real-time as the user progresses through stories
 - Implementation: markAsViewed() called from StoryImageView onLoad callback
 
 Rule 2: User Bubble Status (Unseen vs Seen)
 - UNSEEN: User has at least ONE unviewed story → Shows gradient ring
 - SEEN: ALL stories for that user have been viewed → Shows gray ring, moves to bottom of list
 - The bubble remains "unseen" until the LAST story is viewed
 - Implementation: hasUnseenStories(for:) checks if any story has been viewed by current user
 
 Rule 3: Session Exit Behavior
 - Closing viewer mid-session (before last story): Current user remains "unseen"
 - Finishing ALL stories of a user: User becomes "seen", bubble moves to bottom
 - Swiping to next user before finishing current: Previous user remains "unseen"
 - Auto-dismissal at end of viewing session: Last user becomes "seen"
 
 Rule 4: Resume Behavior
 - Reopening a user's stories always starts from the FIRST unviewed story (by current user)
 - If all stories are viewed (user is "seen"), restart from beginning (re-watch)
 - Implementation: openStory() uses firstIndex(where: { !$0.isViewed(by: currentViewerId) })
 
 Rule 5: Persistence
 - Viewed status persists across app restarts via StoryStorage
 - Only reset on explicit "Reset Stories" action or app reinstall
 - Pull-to-refresh respects existing viewed states
 
 CRITICAL IMPLEMENTATION NOTES:
 - markAsViewed() must check if viewing the LAST story → triggers bubble status update
 - hasUnseenStories() drives the UI bubble appearance (gradient vs gray)
 - Story viewing is tracked per-story, bubble status is derived from all stories
 */

@MainActor
class StoryViewModel: ObservableObject {
    @Published var users: [User] = []
    @Published var stories: [Int: [Story]] = [:] // userId -> stories
    @Published var currentUserIndex: Int = 0
    @Published var currentStoryIndex: Int = 0
    @Published var isPresenting: Bool = false
    @Published var isPaused: Bool = false
    @Published var progress: Double = 0.0
    @Published var showReactionPicker: Bool = false
    @Published var showViewerList: Bool = false
    @Published var isLoading: Bool = false
    @Published var isWaitingForImage: Bool = false {
        didSet {
            if isWaitingForImage {
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
                    if isWaitingForImage {
                        print("⚠️ Image timeout after 10s")
                        isWaitingForImage = false
                    }
                }
            }
        }
    }
    
    // Track if app is in background (used to pause stories)
    private var isInBackground: Bool = false
    
    // Track which user is currently viewing (the logged-in user)
    var currentViewerId: Int = 1 // Default to user 1, should be set from AuthManager
    
    // Track the viewing session order (respects grid order)
    internal var viewingSessionIndices: [Int] = []
    internal var currentPositionInSession: Int = 0
    
    // Track which stories have been marked as viewed in this session to prevent duplicates
    private var markedInSession: Set<UUID> = []
    private let dataSource: StoryDataSource
    private var timer: Timer?
    
    // MARK: - Computed Properties
    var currentUser: User? {
        users.indices.contains(currentUserIndex) ? users[currentUserIndex] : nil
    }
    
    var currentStory: Story? {
        guard let userId = currentUser?.id,
              let userStories = stories[userId],
              userStories.indices.contains(currentStoryIndex) else {
            return nil
        }
        return userStories[currentStoryIndex]
    }
    
    var currentUserStories: [Story] {
        guard let userId = currentUser?.id else { return [] }
        return stories[userId] ?? []
    }
    
    func hasUnseenStories(for userId: Int) -> Bool {
        guard let userStories = stories[userId] else { return false }
        return userStories.contains { !$0.isViewed(by: currentViewerId) }
    }
    
    init(dataSource: StoryDataSource = MockStoryDataSource()) {
        self.dataSource = dataSource
    }
    
    deinit {
        timer?.invalidate()
    }
    
    func loadData(showLoader: Bool = true) async {
        // Only show loader on initial load or when explicitly requested
        if showLoader {
            isLoading = true
        }
        
        do {
            let fetchedUsers = try await dataSource.fetchUsers()
            
            // Load stories for each user
            var newStories: [Int: [Story]] = [:]
            for user in fetchedUsers {
                newStories[user.id] = try await dataSource.fetchStories(for: user.id)
            }
            
            // Update stories first, then users to trigger proper UI updates
            // This ensures that when users array changes, stories are already in sync
            stories = newStories
            users = fetchedUsers
            
            // Debug: Check for unseen stories
            let usersWithUnseen = users.filter { user in
                if let userStories = stories[user.id] {
                    return userStories.contains { !$0.isViewed(by: currentViewerId) }
                }
                return false
            }
            print("📊 LoadData complete: \(users.count) users, \(usersWithUnseen.count) with unseen stories (viewer: \(currentViewerId))")
            if !usersWithUnseen.isEmpty {
                print("   Users with unseen: \(usersWithUnseen.map { $0.id })")
            }
        } catch {
            // Silently handle errors in production
        }
        isLoading = false
    }
    
    func startTimer() {
        timer?.invalidate()
        progress = 0.0
        isPaused = false
        
        // Reduced from 50ms to 100ms to minimize view rebuilds (still smooth at 10 FPS)
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            Task { @MainActor in
                // Don't advance timer if paused OR waiting for image to load
                guard !self.isPaused && !self.isWaitingForImage else { return }
                
                self.progress += 0.02
                
                if self.progress >= 1.0 {
                    self.nextStory()
                }
            }
        }
    }
    
    func pauseTimer() {
        isPaused = true
    }
    
    func resumeTimer() {
        isPaused = false
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
        progress = 0.0
        isPaused = false
    }
    
    // MARK: - App Lifecycle
    
    /// Called when app enters background - pauses timer and story playback
    func handleAppBackgrounded() {
        guard isPresenting else { return }
        
        isInBackground = true
        pauseTimer()
        
        if let user = currentUser {
            print("⏸️ App backgrounded: Pausing story for \(user.name) [\(currentStoryIndex + 1)/\(currentUserStories.count)]")
        }
    }
    
    /// Called when app returns to foreground - resumes timer and story playback
    func handleAppForegrounded() {
        guard isPresenting && isInBackground else { return }
        
        isInBackground = false
        resumeTimer()
        
        if let user = currentUser {
            print("▶️ App foregrounded: Resuming story for \(user.name) [\(currentStoryIndex + 1)/\(currentUserStories.count)]")
        }
    }
    
    func openStory(at userIndex: Int, viewingOrder: [Int] = []) {
        guard userIndex >= 0 && userIndex < users.count else {
            print("⚠️ openStory: Invalid user index \(userIndex)")
            return
        }
        
        // Set up viewing session
        if !viewingOrder.isEmpty {
            viewingSessionIndices = viewingOrder
            currentPositionInSession = viewingOrder.firstIndex(of: userIndex) ?? 0
        } else {
            // Fallback to sequential order from current index
            viewingSessionIndices = Array(userIndex..<users.count)
            currentPositionInSession = 0
        }
        
        let user = users[userIndex]
        currentUserIndex = userIndex
        
        // Check if user has stories
        let userStories = stories[user.id] ?? []
        
        guard !userStories.isEmpty else {
            print("⚠️ openStory: No stories for \(user.name)")
            return
        }
        
        // Find first unread story, or start from 0 if all read
        if let firstUnreadIndex = userStories.firstIndex(where: { !$0.isViewed(by: currentViewerId) }) {
            currentStoryIndex = firstUnreadIndex
            let unseenCount = userStories.filter { !$0.isViewed(by: currentViewerId) }.count
            print("📖 Open: \(user.name) [\(firstUnreadIndex + 1)/\(userStories.count)] | \(unseenCount) unseen (viewer: \(currentViewerId))")
        } else {
            currentStoryIndex = 0
            print("📖 Open: \(user.name) [Re-watch] (viewer: \(currentViewerId))")
        }
        
        isPresenting = true
        isWaitingForImage = true
        startTimer()
        
        // Initial aggressive preloading on open
        preloadUpcomingImages()
        
        // Additional: Preload all stories of current user (if not too many)
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s delay
            await preloadCurrentUserStories()
        }
    }
    
    func nextStory() {
        let currentUserStories = self.currentUserStories
        
        guard !currentUserStories.isEmpty else {
            nextUser()
            return
        }
        
        if currentStoryIndex < currentUserStories.count - 1 {
            currentStoryIndex += 1
            isWaitingForImage = true
            startTimer()
            HapticManager.shared.impact(style: .light)
            
            if let user = currentUser {
                print("➡️ Next story: \(user.name) [\(currentStoryIndex + 1)/\(currentUserStories.count)]")
            }
            
            // Preload upcoming images
            preloadUpcomingImages()
        } else {
            // Reached end of current user's stories
            if let userId = currentUser?.id, let user = currentUser {
                let allViewed = hasViewedAllStories(for: userId)
                print("🏁 Finished \(user.name)'s stories - All viewed: \(allViewed ? "YES ✅" : "NO ⚠️")")
            }
            nextUser()
        }
    }
    
    func previousStory() {
        guard !currentUserStories.isEmpty else {
            previousUser()
            return
        }
        
        if currentStoryIndex > 0 {
            currentStoryIndex -= 1
            isWaitingForImage = true
            startTimer()
            HapticManager.shared.impact(style: .light)
            
            if let user = currentUser {
                print("⬅️ Previous story: \(user.name) [\(currentStoryIndex + 1)/\(currentUserStories.count)]")
            }
            
            // Preload upcoming images
            preloadUpcomingImages()
        } else {
            previousUser()
        }
    }
    
    func nextUser() {
        guard !users.isEmpty else {
            dismissViewer()
            return
        }
        
        // Check if we're at the last position in the viewing session
        if currentPositionInSession >= viewingSessionIndices.count - 1 {
            // Reached the last user in grid order - auto-dismiss after a short delay
            stopTimer()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                withAnimation(.easeOut(duration: 0.3)) {
                    self?.dismissViewer()
                }
            }
                } else {
            // Move to next user in viewing session
            currentPositionInSession += 1
            let newUserIndex = viewingSessionIndices[currentPositionInSession]
            currentUserIndex = newUserIndex
            currentStoryIndex = 0
            isWaitingForImage = true
            startTimer()
            HapticManager.shared.impact(style: .light)
        }
    }
    
    func previousUser() {
        guard !users.isEmpty else { return }
        
        if currentPositionInSession > 0 {
            currentPositionInSession -= 1
            let newUserIndex = viewingSessionIndices[currentPositionInSession]
            currentUserIndex = newUserIndex
            currentStoryIndex = 0
            isWaitingForImage = true
            startTimer()
            HapticManager.shared.impact(style: .light)
        }
    }
    
    func dismissViewer() {
        // Log exit status for current user
        if let userId = currentUser?.id, let user = currentUser {
            let allViewed = hasViewedAllStories(for: userId)
            let status = allViewed ? "SEEN" : "UNSEEN"
            print("🚪 Exit: \(user.name) [\(currentStoryIndex + 1)/\(currentUserStories.count)] \(status) | Marked:\(markedInSession.count)")
        }
        
        stopTimer()
        isPresenting = false
        showReactionPicker = false
        showViewerList = false
        
        // Clear session tracking
        markedInSession.removeAll()
    }
    
    // MARK: - Story Interactions
    
    /// Marks the current story as viewed and checks if all user stories are now complete
    /// This is called when a story image loads and becomes visible
    func markAsViewed() {
        guard let userId = currentUser?.id else {
            print("⚠️ markAsViewed: No current user")
            return
        }
        
        guard var userStories = stories[userId] else {
            print("⚠️ markAsViewed: No stories for user \(userId)")
            return
        }
        
        guard currentStoryIndex >= 0 && currentStoryIndex < userStories.count else {
            print("⚠️ markAsViewed: Invalid story index \(currentStoryIndex) for user \(userId)")
            return
        }
        
        let storyToMark = userStories[currentStoryIndex]
        
        // Check if already marked in this session to prevent duplicate calls
        if markedInSession.contains(storyToMark.id) {
            print("⏭️ Skip: Already marked in session")
            return
        }
        
        // Check if already viewed by current viewer to avoid redundant updates
        if storyToMark.isViewed(by: currentViewerId) {
            print("⏭️ Skip: Already viewed by user \(currentViewerId)")
            return
        }
        
        // Add to session tracking
        markedInSession.insert(storyToMark.id)
        
        // CRITICAL: Check BEFORE marking as viewed if this will be the LAST unviewed story
        // Count how many stories are currently unviewed by the current viewer
        let unseenCountBefore = userStories.filter { !$0.isViewed(by: currentViewerId) }.count
        let willBeLastUnviewedStory = unseenCountBefore == 1 // Only this story is unviewed
        
        let statesBefore = userStories.map { $0.isViewed(by: currentViewerId) ? "✓" : "○" }.joined()
        print("🔍 Before: [\(statesBefore)] Unseen:\(unseenCountBefore) (viewer: \(currentViewerId))")
        
        // Mark current story as viewed by current viewer
        userStories[currentStoryIndex].markAsViewed(by: currentViewerId)
        
        // CRITICAL: Force SwiftUI to detect the change by creating a new dictionary
        // This is necessary because SwiftUI doesn't detect changes inside dictionary values
        var updatedStories = stories
        updatedStories[userId] = userStories
        stories = updatedStories
        
        // Update in persistent storage
        let story = userStories[currentStoryIndex]
        Task {
            StoryStorage.shared.updateStory(story, for: userId)
        }
        
        // Log the status change
        if let user = currentUser {
            let unseenCount = userStories.filter { !$0.isViewed(by: currentViewerId) }.count
            let status = willBeLastUnviewedStory ? "✅ ALL VIEWED" : "👁️ \(unseenCount) unseen"
            print("👁️ Marked: \(user.name) [\(currentStoryIndex + 1)/\(userStories.count)] | \(status) (viewer: \(currentViewerId))")
        }
    }
    
    /// Helper to check if all stories for a user have been viewed by the current viewer
    /// Returns true if the user has completed viewing all their stories
    func hasViewedAllStories(for userId: Int) -> Bool {
        guard let userStories = stories[userId], !userStories.isEmpty else {
            return true // No stories = considered "viewed"
        }
        return !userStories.contains { !$0.isViewed(by: currentViewerId) }
    }
    
    func toggleReaction(_ reaction: ReactionType) {
        guard let userId = currentUser?.id else { return }
        guard var userStories = stories[userId] else { return }
        guard currentStoryIndex >= 0 && currentStoryIndex < userStories.count else { return }
        
        if userStories[currentStoryIndex].reaction == reaction {
            userStories[currentStoryIndex].reaction = nil
        } else {
            userStories[currentStoryIndex].reaction = reaction
            HapticManager.shared.impact(style: .medium)
        }
        
        // Force SwiftUI to detect the change
        var updatedStories = stories
        updatedStories[userId] = userStories
        stories = updatedStories
        
        // Update in persistent storage
        let story = userStories[currentStoryIndex]
        Task {
            StoryStorage.shared.updateStory(story, for: userId)
        }
        
        showReactionPicker = false
    }
    
    func sendReply(_ text: String) {
        guard let userId = currentUser?.id, !text.isEmpty else { return }
        guard var userStories = stories[userId] else { return }
        guard currentStoryIndex >= 0 && currentStoryIndex < userStories.count else { return }
        
        let reply = Reply(
            id: UUID(),
            userId: 1, // Current user ID (hardcoded for mock)
            text: text,
            timestamp: Date()
        )
        
        userStories[currentStoryIndex].replies.append(reply)
        
        // Force SwiftUI to detect the change
        var updatedStories = stories
        updatedStories[userId] = userStories
        stories = updatedStories
        
        // Update in persistent storage
        let story = userStories[currentStoryIndex]
        Task {
            StoryStorage.shared.updateStory(story, for: userId)
        }
        
        HapticManager.shared.notification(type: .success)
    }
    
    // MARK: - Image Preloading
    
    /// Preload upcoming images for smooth transitions
    /// AGGRESSIVE SLIDING WINDOW STRATEGY:
    /// - Preloads 5-7 stories ahead in current user
    /// - Preloads first 3 stories of next 2 users
    /// - Uses priority system to keep most relevant images
    private func preloadUpcomingImages() {
        var urlsWithPriority: [(url: String, priority: Int)] = []
        var basePriority = 1000
        
        // WINDOW 1: Current user's upcoming stories (HIGH PRIORITY)
        // Preload next 5-7 stories for rapid tapping
        let lookahead = min(7, currentUserStories.count - currentStoryIndex - 1)
        if lookahead > 0 {
            for offset in 1...lookahead {
            let storyIndex = currentStoryIndex + offset
            if storyIndex < currentUserStories.count {
                let story = currentUserStories[storyIndex]
                if isPreloadableUrl(story.imageUrl) {
                    // Closer stories get higher priority
                    let priority = basePriority - offset
                    urlsWithPriority.append((url: story.imageUrl, priority: priority))
                }
            }
        }
        }
        
        // WINDOW 2: Next user's stories (MEDIUM PRIORITY)
        basePriority = 900
        if currentPositionInSession + 1 < viewingSessionIndices.count {
            let nextUserIndex = viewingSessionIndices[currentPositionInSession + 1]
            if nextUserIndex < users.count {
                let nextUser = users[nextUserIndex]
                if let nextUserStories = stories[nextUser.id] {
                    // Preload first 3 stories of next user
                    let nextUserLookahead = min(3, nextUserStories.count)
                    for i in 0..<nextUserLookahead {
                        let story = nextUserStories[i]
                        if isPreloadableUrl(story.imageUrl) {
                            let priority = basePriority - i
                            urlsWithPriority.append((url: story.imageUrl, priority: priority))
                        }
                    }
                }
            }
        }
        
        // WINDOW 3: User after next (LOW PRIORITY)
        basePriority = 800
        if currentPositionInSession + 2 < viewingSessionIndices.count {
            let secondNextUserIndex = viewingSessionIndices[currentPositionInSession + 2]
            if secondNextUserIndex < users.count {
                let secondNextUser = users[secondNextUserIndex]
                if let secondNextUserStories = stories[secondNextUser.id], !secondNextUserStories.isEmpty {
                    // Preload just first 2 stories
                    let lookahead = min(2, secondNextUserStories.count)
                    for i in 0..<lookahead {
                        let story = secondNextUserStories[i]
                        if isPreloadableUrl(story.imageUrl) {
                            let priority = basePriority - i
                            urlsWithPriority.append((url: story.imageUrl, priority: priority))
                        }
                    }
                }
            }
        }
        
        // WINDOW 4: Previous stories (if going backwards) (MEDIUM PRIORITY)
        basePriority = 850
        if currentStoryIndex > 0 {
            // Preload previous 2 stories in case user taps back
            let backwardLookahead = min(2, currentStoryIndex)
            if backwardLookahead > 0 {
                for offset in 1...backwardLookahead {
                let storyIndex = currentStoryIndex - offset
                if storyIndex >= 0 {
                    let story = currentUserStories[storyIndex]
                    if isPreloadableUrl(story.imageUrl) {
                        let priority = basePriority - offset
                        urlsWithPriority.append((url: story.imageUrl, priority: priority))
                    }
                }
            }
            }
        }
        
        // Execute preloading with priorities
        if !urlsWithPriority.isEmpty {
            let stats = ImagePreloader.shared.getCacheStats()
            print("📥 Preload window: \(urlsWithPriority.count) images queued | Cache: \(stats.cached)/40, Loading: \(stats.loading)/8")
            ImagePreloader.shared.preloadBatch(urls: urlsWithPriority)
        }
    }
    
    /// Check if URL can be preloaded (not video or base64)
    private func isPreloadableUrl(_ url: String) -> Bool {
        return !url.hasPrefix("video://") && !url.hasPrefix("data:image")
    }
    
    /// Preload all stories for current user (called after initial load)
    private func preloadCurrentUserStories() async {
        guard !currentUserStories.isEmpty else { return }
        
        var urlsWithPriority: [(url: String, priority: Int)] = []
        let basePriority = 700 // Lower than immediate window
        
        // Preload all remaining stories in current user
        for i in 0..<currentUserStories.count {
            // Skip current story (already loading/loaded)
            guard i != currentStoryIndex else { continue }
            
            let story = currentUserStories[i]
            if isPreloadableUrl(story.imageUrl) {
                // Stories closer to current get slightly higher priority
                let distanceFromCurrent = abs(i - currentStoryIndex)
                let priority = basePriority - distanceFromCurrent
                urlsWithPriority.append((url: story.imageUrl, priority: priority))
            }
        }
        
        if !urlsWithPriority.isEmpty {
            print("🎯 Background: Preloading all \(urlsWithPriority.count) stories for current user")
            ImagePreloader.shared.preloadBatch(urls: urlsWithPriority)
        }
    }
}
