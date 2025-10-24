//
//  StoryImageView.swift
//  InstaRipoff
//
//  Created on 23/10/2025.
//

import SwiftUI
import AVKit

struct StoryImageView: View, Equatable {
    let imageUrl: String
    var onImageLoaded: (() -> Void)? = nil
    
    @State private var player: AVPlayer?
    
    // Equatable conformance - prevent rebuilds when URL hasn't changed
    static func == (lhs: StoryImageView, rhs: StoryImageView) -> Bool {
        return lhs.imageUrl == rhs.imageUrl
    }
    
    var body: some View {
        Group {
            if imageUrl.hasPrefix("video://") {
                // Video story
                if let urlString = imageUrl.components(separatedBy: "video://").last,
                   let url = URL(string: urlString) {
                    ZStack {
                        Color.black
                        
                        if let player = player {
                            VideoPlayer(player: player)
                                .disabled(true)
                        }
                    }
                    .ignoresSafeArea()
                    .onAppear {
                        let newPlayer = AVPlayer(url: url)
                        newPlayer.isMuted = false
                        player = newPlayer
                        player?.play()
                        
                        // Notify that video is loaded
                        onImageLoaded?()
                        
                        // Loop video
                        NotificationCenter.default.addObserver(
                            forName: .AVPlayerItemDidPlayToEndTime,
                            object: player?.currentItem,
                            queue: .main
                        ) { _ in
                            player?.seek(to: .zero)
                            player?.play()
                        }
                    }
                    .onDisappear {
                        player?.pause()
                        player = nil
                    }
                } else {
                    Color.black
                        .overlay(
                            Text("Failed to load video")
                                .foregroundColor(.white)
                        )
                }
            } else if imageUrl.hasPrefix("data:image") {
                // Base64 encoded image
                if let base64String = imageUrl.components(separatedBy: ",").last,
                   let imageData = Data(base64Encoded: base64String),
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .clipped()
                        .task {
                            // Only use .task to avoid duplicate calls
                            onImageLoaded?()
                        }
                } else {
                    Color.black
                        .overlay(
                            Text("Failed to load image")
                                .foregroundColor(.white)
                        )
                        .onAppear {
                            onImageLoaded?()
                        }
                }
            } else {
                // URL image with preloading and caching
                PreloadedOrAsyncImageView(imageUrl: imageUrl, onImageLoaded: onImageLoaded)
                    .equatable()
            }
        }
    }
}

// MARK: - Preloaded or Async Image View
struct PreloadedOrAsyncImageView: View, Equatable {
    let imageUrl: String
    var onImageLoaded: (() -> Void)? = nil
    
    @State private var image: UIImage? = nil
    @State private var isLoading = true
    @State private var hasNotifiedLoad = false
    @State private var hasCheckedCache = false
    
    // Equatable conformance - only rebuild if URL changes
    static func == (lhs: PreloadedOrAsyncImageView, rhs: PreloadedOrAsyncImageView) -> Bool {
        // SwiftUI only rebuilds view if imageUrl changes
        // Closures are not compared (they're reference types anyway)
        return lhs.imageUrl == rhs.imageUrl
    }
    
    // Lightweight init - no cache check to prevent duplicate calls
    init(imageUrl: String, onImageLoaded: (() -> Void)? = nil) {
        self.imageUrl = imageUrl
        self.onImageLoaded = onImageLoaded
    }
    
    var body: some View {
        Group {
            if let image = image {
                // Image is ready (from preload or cache)
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
                    .onAppear {
                        // Notify immediately if preloaded
                        if !hasNotifiedLoad {
                            hasNotifiedLoad = true
                            onImageLoaded?()
                        }
                    }
            } else if isLoading {
                // Still loading
                Color.black
                    .overlay(LoadingSpinner())
            } else {
                // Failed to load
                Color.gray
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "photo.fill")
                                .font(.largeTitle)
                                .foregroundColor(.white.opacity(0.5))
                            Text("Image unavailable")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    )
            }
        }
        .task {
            // Check cache first, then load if needed (runs once per view appearance)
            await checkCacheAndLoad()
        }
    }
    
    private func checkCacheAndLoad() async {
        // Prevent duplicate cache checks from multiple .task invocations
        guard !hasCheckedCache else { return }
        hasCheckedCache = true
        
        // Check preload cache first
        if let preloadedImage = ImagePreloader.shared.getPreloaded(url: imageUrl) {
            self.image = preloadedImage
            self.isLoading = false
            // Only log once per unique URL load
            print("🚀 Instant load from preload cache: \(imageUrl.suffix(40))")
            if !hasNotifiedLoad {
                hasNotifiedLoad = true
                onImageLoaded?()
            }
            return
        }
        
        // Not in cache, load from network
        await loadImage()
    }
    
    private func loadImage() async {
        // Check URLSession cache or download
        guard let url = URL(string: imageUrl) else {
            self.isLoading = false
            if !hasNotifiedLoad {
                hasNotifiedLoad = true
                onImageLoaded?()
            }
            return
        }
        
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Check if it came from cache
            if let httpResponse = response as? HTTPURLResponse,
               let cacheControl = httpResponse.allHeaderFields["Cache-Control"] as? String {
                if cacheControl.contains("max-age") {
                    print("📦 Loaded from URLSession cache: \(imageUrl.suffix(40))")
                }
            }
            
            if let uiImage = UIImage(data: data) {
                self.image = uiImage
                self.isLoading = false
                if !hasNotifiedLoad {
                    hasNotifiedLoad = true
                    onImageLoaded?()
                }
            } else {
                self.isLoading = false
                if !hasNotifiedLoad {
                    hasNotifiedLoad = true
                    onImageLoaded?()
                }
            }
        } catch {
            print("⚠️ Failed to load image: \(imageUrl.suffix(40)) - \(error.localizedDescription)")
            self.isLoading = false
            if !hasNotifiedLoad {
                hasNotifiedLoad = true
                onImageLoaded?()
            }
        }
    }
}

// MARK: - Loading Spinner
struct LoadingSpinner: View {
    @State private var isAnimating = false
    
    var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(Color.white, lineWidth: 2.5)
            .frame(width: 30, height: 30)
            .rotationEffect(.degrees(isAnimating ? 360 : 0))
            .animation(
                Animation.linear(duration: 0.8)
                    .repeatForever(autoreverses: false),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}
