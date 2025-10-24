//
//  StoryViewerView.swift
//  InstaRipoff
//
//  Created on 23/10/2025.
//

import SwiftUI

struct StoryViewerView: View {
    @ObservedObject var viewModel: StoryViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var replyText: String = ""
    @FocusState private var isInputFocused: Bool
    @State private var dragOffset: CGFloat = 0
    @State private var reactionAnimations: [(id: UUID, reaction: ReactionType, point: CGPoint)] = []
    @State private var scrollToIndex: Int? = nil
    @State private var isHandlingProgrammaticChange = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollViewReader { proxy in
                    ScrollView(.horizontal) {
                        LazyHStack(spacing: 0) {
                            ForEach(0..<viewModel.users.count, id: \.self) { index in
                                storyPageView(for: index, geometry: geometry)
                                    .frame(width: geometry.size.width, height: geometry.size.height)
                                    .scrollTransition { effect, phase in
                                        effect
                                            .rotation3DEffect(
                                                .degrees(phase.value * 60),
                                                axis: (x: 0.0, y: 1.0, z: 0.0)
                                            )
                                            .scaleEffect(
                                                x: phase.isIdentity ? 1.0 : 0.95,
                                                y: phase.isIdentity ? 1.0 : 0.95
                                            )
                                    }
                                    .id("page-\(index)-user-\(viewModel.users[index].id)")
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.paging)
                    .scrollIndicators(.hidden)
                    .scrollPosition(id: $scrollToIndex)
                    .scrollDisabled(viewModel.showReactionPicker || isInputFocused)
                    .offset(y: dragOffset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if value.translation.height > 0 && abs(value.translation.height) > abs(value.translation.width) {
                                    dragOffset = value.translation.height
                                    viewModel.pauseTimer()
                                }
                            }
                            .onEnded { value in
                                if value.translation.height > 100 {
                                    viewModel.dismissViewer()
                                }
                                withAnimation(.spring()) {
                                    dragOffset = 0
                                }
                                viewModel.resumeTimer()
                            }
                    )
                    .onChange(of: viewModel.currentUserIndex) { oldIndex, newIndex in
                        if scrollToIndex != newIndex {
                            isHandlingProgrammaticChange = true
                            withAnimation {
                                proxy.scrollTo(newIndex, anchor: .center)
                            }
                            DispatchQueue.main.async {
                                scrollToIndex = newIndex
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                isHandlingProgrammaticChange = false
                            }
                        }
                    }
                }
            }
        }
        .statusBar(hidden: true)
        .onChange(of: scrollToIndex) { oldValue, newValue in
            if let newIndex = newValue, newIndex != viewModel.currentUserIndex, !isHandlingProgrammaticChange {
                handleUserChange(to: newIndex)
            }
        }
        .onChange(of: isInputFocused) { _, focused in
            if focused {
                viewModel.pauseTimer()
            } else {
                viewModel.resumeTimer()
            }
        }
        .onChange(of: viewModel.showReactionPicker) { _, showing in
            if showing {
                viewModel.pauseTimer()
            } else {
                viewModel.resumeTimer()
            }
        }
        .sheet(isPresented: $viewModel.showViewerList) {
            if let story = viewModel.currentStory {
                ViewerListView(viewerIds: story.viewerIds, users: viewModel.users)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
        .onAppear {
            scrollToIndex = viewModel.currentUserIndex
        }
        .onDisappear {
            viewModel.stopTimer()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .background:
                viewModel.handleAppBackgrounded()
            case .active:
                viewModel.handleAppForegrounded()
            case .inactive:
                // Don't pause on inactive - this is triggered by alerts, control center, etc.
                break
            @unknown default:
                break
            }
        }
    }
    
    private func handleUserChange(to newIndex: Int) {
        viewModel.currentUserIndex = newIndex
        
        if let sessionPosition = viewModel.viewingSessionIndices.firstIndex(of: newIndex) {
            viewModel.currentPositionInSession = sessionPosition
        }
        
        viewModel.currentStoryIndex = 0
        viewModel.isWaitingForImage = true
        viewModel.startTimer()
        HapticManager.shared.impact(style: .light)
    }
    
    @ViewBuilder
    func storyPageView(for userIndex: Int, geometry: GeometryProxy) -> some View {
        if userIndex < viewModel.users.count {
            let user = viewModel.users[userIndex]
            let stories = viewModel.stories[user.id] ?? []
            let storyIndex = userIndex == viewModel.currentUserIndex ? viewModel.currentStoryIndex : 0
            let story = stories[safe: storyIndex]
            let isCurrentPage = userIndex == viewModel.currentUserIndex
            
            ZStack {
                if let story = story {
                    StoryImageView(imageUrl: story.imageUrl) {
                        let isMatch = isCurrentPage && viewModel.currentStory?.id == story.id
                        print("📸 Loaded | Page:\(isCurrentPage) Match:\(isMatch) | \(story.id.uuidString.prefix(8))")
                        
                        if isCurrentPage,
                           let currentStory = viewModel.currentStory,
                           currentStory.id == story.id {
                            viewModel.isWaitingForImage = false
                            viewModel.markAsViewed()
                        }
                    }
                    .equatable()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .id(story.id)
                }
                
                VStack(spacing: 0) {
                    StoryProgressBar(
                        segmentCount: stories.count,
                        currentIndex: storyIndex,
                        progress: isCurrentPage ? viewModel.progress : 0
                    )
                    .frame(height: 8)
                    
                    HStack(spacing: 12) {
                        AsyncImage(url: URL(string: user.profilePictureUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color.gray.opacity(0.3)
                        }
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.name)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            
                            if let story = story {
                                Text(story.timeAgo)
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        
                        Spacer()
                        
                        if let story = story {
                            Button(action: {
                                viewModel.showViewerList = true
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "eye.fill")
                                        .font(.system(size: 12))
                                    Text("\(story.viewCount)")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .foregroundColor(.white)
                            }
                        }
                        
                        Button(action: {
                            viewModel.dismissViewer()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background(Color.black.opacity(0.3))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                    
                    // Caption overlay (if present)
                    if let caption = story?.caption {
                        HStack {
                            Text(caption)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color.black.opacity(0.5))
                                        .blur(radius: 1)
                                )
                                .padding(.horizontal, 16)
                            Spacer()
                        }
                        .padding(.top, 4)
                    }
                    
                    Spacer()
                    
                    ReplyInputBar(
                        text: $replyText,
                        isFocused: $isInputFocused,
                        onSend: {
                            viewModel.sendReply(replyText)
                            replyText = ""
                            isInputFocused = false
                        }
                    )
                }
                
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        ReactionButton(
                            currentReaction: story?.reaction,
                            onTap: {
                                if let reaction = story?.reaction {
                                    viewModel.toggleReaction(reaction)
                                } else {
                                    viewModel.showReactionPicker.toggle()
                                }
                            },
                            onLongPress: {
                                viewModel.showReactionPicker = true
                            }
                        )
                        .padding(.trailing, 20)
                        .padding(.bottom, 80)
                    }
                }
                
                if isCurrentPage && viewModel.showReactionPicker {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            ReactionPicker { reaction in
                                let screenWidth = UIScreen.main.bounds.width
                                let screenHeight = UIScreen.main.bounds.height
                                let animPoint = CGPoint(x: screenWidth - 50, y: screenHeight - 150)
                                
                                let animationId = UUID()
                                reactionAnimations.append((id: animationId, reaction: reaction, point: animPoint))
                                
                                viewModel.toggleReaction(reaction)
                                
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                    reactionAnimations.removeAll { $0.id == animationId }
                                }
                            }
                            .padding(.trailing, 20)
                            .padding(.bottom, 140)
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.showReactionPicker)
                }
                
                if isCurrentPage {
                    ForEach(reactionAnimations, id: \.id) { animation in
                        ReactionAnimationView(
                            reaction: animation.reaction,
                            startPoint: animation.point
                        )
                    }
                }
                
                // Pause indicator
                if isCurrentPage && viewModel.isPaused {
                    VStack {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.8))
                            .shadow(color: .black.opacity(0.3), radius: 10)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.isPaused)
                }
                
                if isCurrentPage && !viewModel.showReactionPicker && !isInputFocused {
                    GeometryReader { geo in
                        HStack(spacing: 0) {
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    viewModel.previousStory()
                                }
                                .onLongPressGesture(minimumDuration: 10.0, pressing: { pressing in
                                    if pressing {
                                        viewModel.pauseTimer()
                                    } else {
                                        viewModel.resumeTimer()
                                    }
                                }, perform: {})
                            
                            Color.clear
                                .contentShape(Rectangle())
                                .onLongPressGesture(minimumDuration: 10.0, pressing: { pressing in
                                    if pressing {
                                        viewModel.pauseTimer()
                                    } else {
                                        viewModel.resumeTimer()
                                    }
                                }, perform: {})
                            
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    viewModel.nextStory()
                                }
                                .onLongPressGesture(minimumDuration: 10.0, pressing: { pressing in
                                    if pressing {
                                        viewModel.pauseTimer()
                                    } else {
                                        viewModel.resumeTimer()
                                    }
                                }, perform: {})
                        }
                        .padding(.top, 80)
                        .padding(.bottom, 200)
                    }
                }
            }
        } else {
            Color.black
        }
    }
}
