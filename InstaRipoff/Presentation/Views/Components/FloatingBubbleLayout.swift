//
//  FloatingBubbleLayout.swift
//  InstaRipoff
//
//  Created on 23/10/2025.
//

import SwiftUI

struct FloatingBubbleLayout: View {
    let users: [User]
    let stories: [Int: [Story]]
    let currentUserId: Int?
    let onTapUser: (Int, [Int]) -> Void  // (userIndex, viewingOrder)
    let onCreateStory: () -> Void
    let onRefresh: () async -> Void
    let newlyPostedUserId: Int?
    
    @State private var positions: [Int: CGPoint] = [:]
    @State private var animationOffsets: [Int: CGFloat] = [:]
    @State private var disableLayoutAnimation = true  // Start disabled for initial load
    @State private var animatingUserIds: Set<Int> = []
    @State private var previousUserOrder: [Int] = []
    @State private var appearedBubbles: Set<Int> = []
    @State private var initialLoadComplete = false
    @State private var lastStoriesHash: Int = 0  // Track when stories change
    @Namespace private var bubbleNamespace
    
    // Grid configuration for bubble positioning
    private let columns = 3
    private let bubbleSize: CGFloat = 100  // Same size for all bubbles
    private let spacing: CGFloat = 20
    
    // Computed property to track current sort order
    private var currentSortOrder: [Int] {
        let sorted = sortedUsers()
        return sorted.map { $0.id }
    }
    
    var body: some View {
        contentView
            .modifier(ChangeDetectionModifiers(
                users: users,
                stories: stories,
                currentSortOrder: currentSortOrder,
                newlyPostedUserId: newlyPostedUserId,
                onUsersChange: handleUsersChange,
                onStoriesChange: handleStoriesChange,
                onSortOrderChange: detectAndAnimateChanges,
                onNewlyPostedStory: handleNewlyPostedStory,
                onAppear: handleAppear
            ))
    }
    
    private var contentView: some View {
        GeometryReader { geometry in
            ScrollView(.vertical, showsIndicators: true) {
                ZStack(alignment: .topLeading) {
                    currentUserBubbleView(geometry: geometry)
                    userBubblesView(geometry: geometry)
                }
                .frame(width: geometry.size.width, height: max(calculateContentHeight(), geometry.size.height))
            }
            .refreshable {
                await handleRefresh()
            }
        }
    }
    
    @ViewBuilder
    private func currentUserBubbleView(geometry: GeometryProxy) -> some View {
        if let currentUser = users.first(where: { $0.id == currentUserId }) {
            let gridWidth = CGFloat(columns) * bubbleSize + CGFloat(columns - 1) * spacing
            let startX = (geometry.size.width - gridWidth) / 2
            let firstX = startX + bubbleSize / 2
            let firstY: CGFloat = 20 + bubbleSize / 2
            let currentUserStories = stories[currentUser.id] ?? []
            let hasStories = !currentUserStories.isEmpty
            let isAnimating = animatingUserIds.contains(currentUser.id)
            
            createStoryBubble(user: currentUser, hasStories: hasStories, isAnimating: isAnimating)
                .position(x: firstX, y: firstY)
                .animation(disableLayoutAnimation ? nil : .spring(response: 0.6, dampingFraction: 0.7), value: firstX)
                .animation(disableLayoutAnimation ? nil : .spring(response: 0.6, dampingFraction: 0.7), value: firstY)
                .onTapGesture {
                    // Tap: Create new story (Instagram-style)
                    handleCurrentUserTap(currentUser: currentUser, hasStories: hasStories, storyCount: currentUserStories.count)
                }
                .onLongPressGesture(minimumDuration: 0.5) {
                    // Long press: View own stories if they exist
                    if hasStories, let actualIndex = users.firstIndex(where: { $0.id == currentUser.id }) {
                        HapticManager.shared.impact(style: .medium)
                        let viewingOrder = [actualIndex]
                        onTapUser(actualIndex, viewingOrder)
                    }
                }
        }
    }
    
    @ViewBuilder
    private func userBubblesView(geometry: GeometryProxy) -> some View {
        ForEach(Array(sortedUsers().enumerated()), id: \.element.id) { index, user in
            userBubbleView(index: index, user: user, geometry: geometry)
        }
    }
    
    @ViewBuilder
    private func userBubbleView(index: Int, user: User, geometry: GeometryProxy) -> some View {
        let hasUnseen = hasUnseenStories(for: user.id)
        let isRecent = isRecentStory(for: user.id)
        let position = calculatePosition(for: index, hasUnseen: hasUnseen, in: geometry.size)
        let isAnimating = animatingUserIds.contains(user.id)
        let hasAppeared = appearedBubbles.contains(user.id)
        
        Button(action: {
            handleUserBubbleTap(user: user)
        }) {
            FloatingBubble(
                user: user,
                hasUnseen: hasUnseen,
                isRecent: isRecent,
                size: bubbleSize,
                offset: animationOffsets[user.id] ?? 0,
                isAnimating: isAnimating
            )
        }
        .matchedGeometryEffect(id: user.id, in: bubbleNamespace)
        .position(position)
        .opacity(hasAppeared ? 1 : 0)
        .scaleEffect(hasAppeared ? 1 : 0.3)
        .zIndex(isAnimating ? 100 : Double(index))
        .animation(disableLayoutAnimation ? nil : .spring(response: 0.4, dampingFraction: 0.75), value: position)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: hasAppeared)
    }
    
    private func handleCurrentUserTap(currentUser: User, hasStories: Bool, storyCount: Int) {
        // Instagram-style behavior: Plus button always creates new story
        // To view own stories, user can tap and hold or we could add a separate gesture
        HapticManager.shared.impact(style: .medium)
        onCreateStory()
    }
    
    private func handleUserBubbleTap(user: User) {
        let viewingOrder = sortedUsers().compactMap { sortedUser in
            users.firstIndex(where: { $0.id == sortedUser.id })
        }
        
        if let actualIndex = users.firstIndex(where: { $0.id == user.id }) {
            onTapUser(actualIndex, viewingOrder)
        }
    }
    
    private func handleRefresh() async {
        HapticManager.shared.impact(style: .medium)
        
        let storyCountBefore = stories.values.map { $0.count }.reduce(0, +)
        await onRefresh()
        let storyCountAfter = stories.values.map { $0.count }.reduce(0, +)
        let hasNewContent = storyCountAfter > storyCountBefore
        
        if hasNewContent {
            HapticManager.shared.notification(type: .success)
        } else {
            HapticManager.shared.impact(style: .light)
        }
    }
    
    private func handleAppear() {
        startFloatingAnimation()
        
        if !initialLoadComplete {
            let sortedUsersList = sortedUsers()
            
            for (index, user) in sortedUsersList.enumerated() {
                let delay = Double(index) * 0.12 // 120ms between each bubble for better visibility
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        _ = appearedBubbles.insert(user.id)
                    }
                    // Individual haptic for each bubble
                    HapticManager.shared.impact(style: .light)
                }
            }
            
            // Enable animations after all bubbles appear
            let totalDelay = Double(sortedUsersList.count) * 0.12 + 0.2
            DispatchQueue.main.asyncAfter(deadline: .now() + totalDelay) {
                disableLayoutAnimation = false
                initialLoadComplete = true
            }
        } else {
            appearedBubbles = Set(sortedUsers().map { $0.id })
        }
    }
    
    private func handleUsersChange(_ newUsers: [User]) {
        for user in newUsers {
            if !appearedBubbles.contains(user.id) {
                appearedBubbles.insert(user.id)
            }
        }
    }
    
    private func handleStoriesChange(oldStories: [Int: [Story]], newStories: [Int: [Story]]) {
        // Count changes for summary
        var countChanges: [String] = []
        var viewChanges: [String] = []
        
        for userId in newStories.keys {
            let oldUserStories = oldStories[userId] ?? []
            let newUserStories = newStories[userId] ?? []
            
            if oldUserStories.count != newUserStories.count {
                if let user = users.first(where: { $0.id == userId }) {
                    countChanges.append("\(user.name): \(oldUserStories.count)→\(newUserStories.count)")
                }
            }
            
            let oldUnseenCount = oldUserStories.filter { !$0.isViewed(by: currentUserId ?? 1) }.count
            let newUnseenCount = newUserStories.filter { !$0.isViewed(by: currentUserId ?? 1) }.count
            
            if oldUnseenCount != newUnseenCount {
                if let user = users.first(where: { $0.id == userId }) {
                    viewChanges.append("\(user.name): \(oldUnseenCount)→\(newUnseenCount) unseen")
                }
            }
        }
        
        if !countChanges.isEmpty || !viewChanges.isEmpty {
            let changes = (countChanges + viewChanges).joined(separator: ", ")
            print("📦 Stories: \(changes)")
        }
    }
    
    private func handleNewlyPostedStory(_ userId: Int?) {
        guard let userId = userId else { return }
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            _ = animatingUserIds.insert(userId)
        }
        
        HapticManager.shared.notification(type: .success)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            HapticManager.shared.impact(style: .medium)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                _ = animatingUserIds.remove(userId)
            }
        }
    }
    
    private func detectAndAnimateChanges(oldOrder: [Int], newOrder: [Int]) {
        // Don't animate during initial load
        guard initialLoadComplete else { return }
        
        // Find users that changed position or are new
        var usersToAnimate = Set<Int>()
        
        // Check for new users (not in old order)
        for userId in newOrder {
            if !oldOrder.contains(userId) {
                usersToAnimate.insert(userId)
            }
        }
        
        // Check for users that moved up (ANY position change towards front)
        for (newIndex, userId) in newOrder.enumerated() {
            if let oldIndex = oldOrder.firstIndex(of: userId) {
                // If user moved up (to lower index = closer to front)
                if oldIndex > newIndex {
                    usersToAnimate.insert(userId)
                }
            }
        }
        
        // Only animate if changes detected
        guard !usersToAnimate.isEmpty else { return }
        
        let userNames = usersToAnimate.compactMap { id in
            users.first(where: { $0.id == id })?.name
        }.joined(separator: ", ")
        print("🎬 Animating: \(userNames)")
        
        // Trigger haptic
        HapticManager.shared.impact(style: .medium)
        
        // Start animation
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            animatingUserIds = usersToAnimate
        }
        
        // Clear animation state after completion (0.4s spring + 0.3s for scale pulse)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation {
                animatingUserIds.removeAll()
            }
        }
    }
    
    private func calculateContentHeight() -> CGFloat {
        let totalUsers = sortedUsers().count + 1 // +1 for Create Story
        let rows = (totalUsers + columns - 1) / columns
        return 20 + CGFloat(rows) * (bubbleSize + spacing + 10) + 100
    }
    
    private func createStoryBubble(user: User, hasStories: Bool, isAnimating: Bool) -> some View {
        ZStack {
            // Animation glow for newly posted story
            if isAnimating {
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color(red: 0.51, green: 0.20, blue: 0.89),
                                Color(red: 0.89, green: 0.20, blue: 0.51),
                                Color(red: 0.89, green: 0.51, blue: 0.20)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 4
                    )
                    .frame(width: bubbleSize + 10, height: bubbleSize + 10)
                    .opacity(0.8)
                    .blur(radius: 3)
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.6).repeatCount(2, autoreverses: true), value: isAnimating)
            }
            
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.15), Color.pink.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: bubbleSize, height: bubbleSize)
            
            // Gradient ring if user has stories
            if hasStories {
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color(red: 0.51, green: 0.20, blue: 0.89),
                                Color(red: 0.89, green: 0.20, blue: 0.51),
                                Color(red: 0.89, green: 0.51, blue: 0.20)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .frame(width: bubbleSize - 5, height: bubbleSize - 5)
            } else {
                Circle()
                    .strokeBorder(Color.gray.opacity(0.3), lineWidth: 2.5, antialiased: true)
                    .frame(width: bubbleSize - 5, height: bubbleSize - 5)
            }
            
            AsyncImage(url: URL(string: user.profilePictureUrl)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure(_):
                    Color.gray.opacity(0.3)
                case .empty:
                    Color.gray.opacity(0.2)
                @unknown default:
                    Color.gray.opacity(0.3)
                }
            }
            .frame(width: bubbleSize - 20, height: bubbleSize - 20)
            .clipShape(Circle())
            
            // Plus button overlay - ALWAYS show for current user (Instagram style)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.9)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .shadow(color: Color.blue.opacity(0.4), radius: 4, x: 0, y: 2)
                        .offset(x: 10, y: 10)
                }
            }
            .frame(width: bubbleSize - 20, height: bubbleSize - 20)
            
            VStack {
                Spacer()
                Text(hasStories ? "Your Story" : "Create Story")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemBackground).opacity(0.9))
                    .cornerRadius(8)
                    .offset(y: 15)
            }
            .frame(height: bubbleSize)
        }
        .scaleEffect(isAnimating ? 1.1 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6).repeatCount(2, autoreverses: true), value: isAnimating)
    }
    
    private func calculatePosition(for index: Int, hasUnseen: Bool, in size: CGSize) -> CGPoint {
        // Calculate centered grid
        let gridWidth = CGFloat(columns) * bubbleSize + CGFloat(columns - 1) * spacing
        let startX = (size.width - gridWidth) / 2
        
        // Account for Create Story being first (offset all by 1)
        let gridIndex = index + 1
        let row = gridIndex / columns
        let col = gridIndex % columns
        
        let x = startX + bubbleSize / 2 + CGFloat(col) * (bubbleSize + spacing)
        let y = 20 + bubbleSize / 2 + CGFloat(row) * (bubbleSize + spacing + 10)
        
        return CGPoint(x: x, y: y)
    }
    
    private func startFloatingAnimation() {
        for user in users {
            // Only animate bubbles with unseen stories
            if hasUnseenStories(for: user.id) {
                animationOffsets[user.id] = 0
                
                // Random floating animation
                let delay = Double.random(in: 0...1)
                let duration = Double.random(in: 2.5...4.0)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(
                        .easeInOut(duration: duration)
                        .repeatForever(autoreverses: true)
                    ) {
                        animationOffsets[user.id] = CGFloat.random(in: -10...10)
                    }
                }
            } else {
                // No floating for seen stories
                animationOffsets[user.id] = 0
            }
        }
    }
    
    private func sortedUsers() -> [User] {
        users
            .filter { $0.id != currentUserId }
            .sorted { user1, user2 in
                let hasUnseen1 = hasUnseenStories(for: user1.id)
                let hasUnseen2 = hasUnseenStories(for: user2.id)
                
                // Unread stories first
                if hasUnseen1 != hasUnseen2 {
                    return hasUnseen1
                }
                
                // Within same status, most recent first
                let recent1 = stories[user1.id]?.first?.timestamp ?? .distantPast
                let recent2 = stories[user2.id]?.first?.timestamp ?? .distantPast
                
                return recent1 > recent2
            }
    }
    
    private func hasUnseenStories(for userId: Int) -> Bool {
        guard let userStories = stories[userId] else {
            return false
        }
        return userStories.contains { !$0.isViewed(by: currentUserId ?? 1) }
    }
    
    private func isRecentStory(for userId: Int) -> Bool {
        guard let userStories = stories[userId],
              let firstStory = userStories.first else { return false }
        return Date().timeIntervalSince(firstStory.timestamp) < 3600
    }
}

struct FloatingBubble: View {
    let user: User
    let hasUnseen: Bool
    let isRecent: Bool
    let size: CGFloat
    let offset: CGFloat
    let isAnimating: Bool
    
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.0
    @State private var animationScale: CGFloat = 1.0
    @State private var animationGlow: Double = 0.0
    
    private let unseenGradient = LinearGradient(
        colors: [
            Color(red: 0.51, green: 0.20, blue: 0.89),
            Color(red: 0.89, green: 0.20, blue: 0.51),
            Color(red: 0.89, green: 0.51, blue: 0.20)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    var body: some View {
        ZStack {
            // Animation glow ring for repositioning
            if isAnimating {
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white, Color.blue.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 4
                    )
                    .frame(width: size + 10, height: size + 10)
                    .opacity(animationGlow)
                    .blur(radius: 3)
            }
            
            // Gradient ring around profile picture (Instagram style)
            if hasUnseen {
                Circle()
                    .strokeBorder(unseenGradient, lineWidth: 3)
                    .frame(width: size - 8, height: size - 8)
                    .scaleEffect(pulseScale)
            } else {
                Circle()
                    .strokeBorder(Color.gray.opacity(0.3), lineWidth: 2)
                    .frame(width: size - 8, height: size - 8)
            }
            
            // Glow for recent
            if isRecent && hasUnseen {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.purple.opacity(0.6),
                                Color.pink.opacity(0.3),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: size * 0.3,
                            endRadius: size * 0.6
                        )
                    )
                    .frame(width: size + 20, height: size + 20)
                    .opacity(glowOpacity)
                    .blur(radius: 10)
            }
            
            // Main bubble
            ZStack {
                Circle()
                    .fill(
                        hasUnseen ?
                        LinearGradient(
                            colors: [Color.purple.opacity(0.2), Color.pink.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [Color.gray.opacity(0.1), Color.gray.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
                
                if hasUnseen {
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.51, green: 0.20, blue: 0.89),
                                    Color(red: 0.89, green: 0.20, blue: 0.51),
                                    Color(red: 0.89, green: 0.51, blue: 0.20)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .frame(width: size - 5, height: size - 5)
                        .scaleEffect(pulseScale)
                } else {
                    Circle()
                        .strokeBorder(Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: size - 5, height: size - 5)
                }
                
                AsyncImage(url: URL(string: user.profilePictureUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure(_):
                        Color.gray.opacity(0.3)
                    case .empty:
                        Color.gray.opacity(0.2)
                    @unknown default:
                        Color.gray.opacity(0.3)
                    }
                }
                .frame(width: size - 15, height: size - 15)
                .clipShape(Circle())
            }
            .shadow(color: hasUnseen ? Color.purple.opacity(0.3) : Color.black.opacity(0.1),
                    radius: hasUnseen ? 15 : 5, x: 0, y: 5)
            
            // Name label
            VStack {
                Spacer()
                Text(user.name)
                    .font(.system(size: 11, weight: hasUnseen ? .bold : .regular))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemBackground).opacity(0.9))
                    .cornerRadius(8)
                    .offset(y: 12)
            }
            .frame(height: size)
        }
        .scaleEffect(animationScale)
        .offset(y: offset)
        .onAppear {
            if hasUnseen {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    pulseScale = 1.05
                }
            }
            if isRecent {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    glowOpacity = 1.0
                }
            }
        }
        .onChange(of: isAnimating) { _, animating in
            if animating {
                // Scale pulse: 1.0 → 1.15 → 1.0
                animationScale = 1.0
                animationGlow = 0.0
                
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                    animationScale = 1.15
                    animationGlow = 0.3
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.75)) {
                        animationScale = 1.0
                        animationGlow = 0.0
                    }
                }
            }
        }
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ChangeDetectionModifiers: ViewModifier {
    let users: [User]
    let stories: [Int: [Story]]
    let currentSortOrder: [Int]
    let newlyPostedUserId: Int?
    let onUsersChange: ([User]) -> Void
    let onStoriesChange: ([Int: [Story]], [Int: [Story]]) -> Void
    let onSortOrderChange: ([Int], [Int]) -> Void
    let onNewlyPostedStory: (Int?) -> Void
    let onAppear: () -> Void
    
    func body(content: Content) -> some View {
        let appearView = content.onAppear { onAppear() }
        let usersView = appearView.onChange(of: users) { _, newUsers in
            onUsersChange(newUsers)
        }
        let storiesView = usersView.onChange(of: stories) { oldStories, newStories in
            onStoriesChange(oldStories, newStories)
        }
        let sortView = storiesView.onChange(of: currentSortOrder) { oldOrder, newOrder in
            onSortOrderChange(oldOrder, newOrder)
        }
        let finalView = sortView.onChange(of: newlyPostedUserId) { _, userId in
            onNewlyPostedStory(userId)
        }
        
        return finalView
    }
}

#Preview {
    FloatingBubbleLayout(
        users: [
            User(id: 1, name: "Neo", profilePictureUrl: "https://i.pravatar.cc/300?u=1"),
            User(id: 2, name: "Trinity", profilePictureUrl: "https://i.pravatar.cc/300?u=2"),
            User(id: 3, name: "Morpheus", profilePictureUrl: "https://i.pravatar.cc/300?u=3"),
            User(id: 4, name: "Smith", profilePictureUrl: "https://i.pravatar.cc/300?u=4"),
        ],
        stories: [:],
        currentUserId: 1,
        onTapUser: { _, _ in },
        onCreateStory: { },
        onRefresh: { },
        newlyPostedUserId: nil
    )
}
