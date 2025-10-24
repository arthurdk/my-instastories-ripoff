//
//  StoryEditorView.swift
//  InstaRipoff
//
//  Created on 23/10/2025.
//

import SwiftUI
import AVKit

struct StoryEditorView: View {
    let image: UIImage
    let onDiscard: () -> Void
    let onPost: (UIImage, String?) -> Void
    
    @State private var text: String = ""
    @State private var caption: String = ""
    @State private var showTextEditor = false
    @State private var showCaptionEditor = false
    @State private var selectedFilter: FilterType = .none
    @State private var showFilterPicker = false
    @State private var textPosition: CGPoint = .zero
    @State private var isDraggingText = false
    @State private var isPosting = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background image with filter (fit to screen)
                Image(uiImage: filteredImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .background(Color.black)
                
                // Text overlay (if any) - draggable
                if !text.isEmpty {
                    Text(text)
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
                        .padding()
                        .position(textPosition == .zero ? CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2) : textPosition)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    isDraggingText = true
                                    textPosition = value.location
                                }
                                .onEnded { _ in
                                    isDraggingText = false
                                }
                        )
                        .opacity(isDraggingText ? 0.7 : 1.0)
                }
                
                // Top toolbar - only dismiss button
                VStack {
                    HStack {
                        Spacer()
                        
                        Button {
                            onDiscard()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        .padding(.trailing, 20)
                        .padding(.top, 50)
                    }
                    
                    Spacer()
                    
                    // Caption display (if entered)
                    if !caption.isEmpty {
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
                        .padding(.bottom, 200)
                    }
                    
                    Spacer()
                    
                    // Bottom tools and Share button
                    VStack(spacing: 20) {
                        // Tools with improved visibility
                        HStack(spacing: 30) {
                            Button(action: { showCaptionEditor = true }) {
                                VStack(spacing: 4) {
                                    Image(systemName: "text.bubble")
                                        .font(.system(size: 24))
                                    Text("Caption")
                                        .font(.system(size: 12))
                                }
                                .foregroundColor(.white)
                                .frame(width: 70, height: 70)
                                .background(Color.black.opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            
                            Button(action: { showTextEditor = true }) {
                                VStack(spacing: 4) {
                                    Image(systemName: "textformat")
                                        .font(.system(size: 24))
                                    Text("Text")
                                        .font(.system(size: 12))
                                }
                                .foregroundColor(.white)
                                .frame(width: 70, height: 70)
                                .background(Color.black.opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            
                            Button(action: { showFilterPicker.toggle() }) {
                                VStack(spacing: 4) {
                                    Image(systemName: "camera.filters")
                                        .font(.system(size: 24))
                                    Text("Filter")
                                        .font(.system(size: 12))
                                }
                                .foregroundColor(.white)
                                .frame(width: 70, height: 70)
                                .background(Color.black.opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                        
                        // Share button as primary CTA at bottom
                        Button(action: {
                            guard !isPosting else { return }
                            isPosting = true
                            HapticManager.shared.impact(style: .medium)
                            onPost(renderedImage(), caption.isEmpty ? nil : caption)
                        }) {
                            HStack(spacing: 8) {
                                if isPosting {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "paperplane.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                Text(isPosting ? "Posting..." : "Share to Story")
                                    .font(.system(size: 18, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(
                                    colors: [Color(red: 0.51, green: 0.20, blue: 0.89), Color(red: 0.89, green: 0.20, blue: 0.51)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                            .shadow(color: Color.purple.opacity(0.4), radius: 12, x: 0, y: 6)
                            .opacity(isPosting ? 0.8 : 1.0)
                        }
                        .disabled(isPosting)
                        .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 40)
                }
                
                // Filter picker
                if showFilterPicker {
                    VStack {
                        Spacer()
                        FilterPickerView(selectedFilter: $selectedFilter)
                            .transition(.move(edge: .bottom))
                    }
                }
                
                // Text editor sheet
                if showTextEditor {
                    Color.black.opacity(0.8)
                        .ignoresSafeArea()
                        .overlay(
                            VStack(spacing: 20) {
                                TextField("Add text...", text: $text)
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .padding()
                                
                                Button("Done") {
                                    showTextEditor = false
                                }
                                .foregroundColor(.white)
                                .padding()
                            }
                        )
                        .transition(.opacity)
                }
                
                // Caption editor sheet
                if showCaptionEditor {
                    Color.black.opacity(0.9)
                        .ignoresSafeArea()
                        .overlay(
                            VStack(spacing: 20) {
                                Text("Add a caption")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.top, 40)
                                
                                TextField("Write a caption...", text: $caption, axis: .vertical)
                                    .font(.system(size: 18))
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                                    .padding(.horizontal)
                                    .lineLimit(3...6)
                                
                                HStack(spacing: 20) {
                                    Button("Cancel") {
                                        showCaptionEditor = false
                                    }
                                    .foregroundColor(.white)
                                    .padding()
                                    
                                    Button("Done") {
                                        showCaptionEditor = false
                                    }
                                    .foregroundColor(.blue)
                                    .padding()
                                }
                                
                                Spacer()
                            }
                        )
                        .transition(.opacity)
                }
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut, value: showFilterPicker)
        .animation(.easeInOut, value: showTextEditor)
        .animation(.easeInOut, value: showCaptionEditor)
    }
    
    private var filteredImage: UIImage {
        guard selectedFilter != .none else { return image }
        return image.applyFilter(selectedFilter) ?? image
    }
    
    private func renderedImage() -> UIImage {
        let imageSize = image.size
        let finalPosition = textPosition == .zero ? CGPoint(x: imageSize.width / 2, y: imageSize.height / 2) : textPosition
        
        let renderer = ImageRenderer(content: 
            ZStack {
                Image(uiImage: filteredImage)
                    .resizable()
                    .scaledToFill()
                
                if !text.isEmpty {
                    Text(text)
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
                        .position(finalPosition)
                }
            }
            .frame(width: imageSize.width, height: imageSize.height)
        )
        
        return renderer.uiImage ?? filteredImage
    }
}

// Video Editor (simplified for now)
struct VideoEditorView: View {
    let videoURL: URL
    let onDiscard: () -> Void
    let onPost: (URL) -> Void
    
    @State private var player: AVPlayer?
    @State private var isPosting = false
    
    var body: some View {
        ZStack {
            // Video preview
            if let player = player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
                    .onAppear {
                        player.isMuted = false
                        player.play()
                    }
            } else {
                Color.black.ignoresSafeArea()
            }
            
            VStack {
                HStack {
                    Spacer()
                    
                    Button {
                        player?.pause()
                        onDiscard()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 50)
                }
                
                Spacer()
                
                // Share button at bottom
                Button {
                    guard !isPosting else { return }
                    isPosting = true
                    player?.pause()
                    HapticManager.shared.impact(style: .medium)
                    onPost(videoURL)
                } label: {
                    HStack(spacing: 8) {
                        if isPosting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        Text(isPosting ? "Posting..." : "Share to Story")
                            .font(.system(size: 18, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.51, green: 0.20, blue: 0.89), Color(red: 0.89, green: 0.20, blue: 0.51)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: Color.purple.opacity(0.4), radius: 12, x: 0, y: 6)
                    .opacity(isPosting ? 0.8 : 1.0)
                }
                .disabled(isPosting)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            player = AVPlayer(url: videoURL)
            player?.isMuted = false
            player?.play()
        }
        .onDisappear {
            player?.pause()
        }
    }
}
