//
//  StoryListView.swift
//  InstaRipoff
//
//  Created on 23/10/2025.
//

import SwiftUI

struct StoryListView: View {
    @StateObject private var viewModel = StoryViewModel()
    @EnvironmentObject var authManager: AuthManager
    @State private var showCreateStory = false
    @State private var shouldReloadStories = false
    @State private var isRefreshing = false
    @State private var newlyPostedStory = false
    @State private var showHint = false
    @AppStorage("hasSeenStoryCreationHint") private var hasSeenHint = false
    
    var body: some View {
        NavigationView {
            ZStack {
                FloatingBubbleLayout(
                    users: viewModel.users,
                    stories: viewModel.stories,
                    currentUserId: authManager.currentUser?.id,
                    onTapUser: { userIndex, viewingOrder in
                        // Validate index before opening
                        guard userIndex >= 0 && userIndex < viewModel.users.count else {
                            return
                        }
                        viewModel.openStory(at: userIndex, viewingOrder: viewingOrder)
                    },
                    onCreateStory: {
                        showCreateStory = true
                    },
                    onRefresh: {
                        await performRefresh()
                    },
                    newlyPostedUserId: newlyPostedStory ? authManager.currentUser?.id : nil
                )
                .overlay(alignment: .top) {
                    // Hint bubble for first-time users
                    if showHint {
                        VStack(spacing: 8) {
                            Text("💡 Tap your story to create")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)
                            Text("Long press to view your stories")
                                .font(.system(size: 12))
                                .foregroundColor(.primary.opacity(0.7))
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.3), radius: 16, x: 0, y: 4)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                        .padding(.top, 140)
                        .transition(.scale.combined(with: .opacity))
                        .onTapGesture {
                            withAnimation {
                                showHint = false
                                hasSeenHint = true
                            }
                        }
                    }
                }
                
                // Show loader only on initial load (when users array is empty)
                if viewModel.isLoading && viewModel.users.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemBackground))
                }
            }
            .navigationTitle("Stories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                // Leading: Create Story button
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showCreateStory = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(red: 0.51, green: 0.20, blue: 0.89), Color(red: 0.89, green: 0.20, blue: 0.51)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
                
                // Trailing: Profile menu
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        if let currentUser = authManager.currentUser {
                            Text("Logged in as \(currentUser.name)")
                        }
                        
                        Divider()
                        
                        Button(action: {
                            Task {
                                await MainActor.run {
                                    StoryStorage.shared.resetToDefaults()
                                }
                                await viewModel.loadData(showLoader: false)
                            }
                        }) {
                            Label("Reset Stories", systemImage: "arrow.counterclockwise")
                        }
                        
                        Button(role: .destructive, action: {
                            authManager.logout()
                        }) {
                            Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        if let currentUser = authManager.currentUser {
                            AsyncImage(url: URL(string: currentUser.profilePictureUrl)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 20))
                            }
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 20))
                        }
                    }
                }
            })
        }
        .fullScreenCover(isPresented: $viewModel.isPresenting) {
            StoryViewerView(viewModel: viewModel)
        }
        .fullScreenCover(isPresented: $showCreateStory) {
            CameraView(shouldReloadStories: $shouldReloadStories)
                .environmentObject(authManager)
        }
        .task {
            // Set the current viewer ID from the logged-in user
            if let currentUserId = authManager.currentUser?.id {
                viewModel.currentViewerId = currentUserId
            }
            
            await viewModel.loadData()
            
            // Show hint after a short delay on first launch
            if !hasSeenHint {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        showHint = true
                    }
                    
                    // Auto-dismiss hint after 5 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                        withAnimation {
                            showHint = false
                            hasSeenHint = true
                        }
                    }
                }
            }
        }
        .onChange(of: shouldReloadStories) { _, shouldReload in
            if shouldReload {
                Task {
                    // Set flag for newly posted story animation
                    newlyPostedStory = true
                    
                    // Don't show loader when reloading after posting story
                    await viewModel.loadData(showLoader: false)
                    shouldReloadStories = false
                    
                    // Clear animation flag after animation completes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        newlyPostedStory = false
                    }
                }
            }
        }
    }
    
    private func performRefresh() async {
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 800_000_000) // 0.8s
        
        let didAddNewStories = StoryStorage.shared.addRandomNewStories()
        
        print("🔄 Pull to refresh - didAddNewStories: \(didAddNewStories)")
        
        // Always reload to ensure UI updates and triggers reordering animation
        await viewModel.loadData(showLoader: false)
    }
}
