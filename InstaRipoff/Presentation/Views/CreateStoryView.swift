//
//  CreateStoryView.swift
//  InstaRipoff
//
//  Created on 23/10/2025.
//

import SwiftUI
import PhotosUI
import AVKit

struct CreateStoryView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    @Binding var shouldReloadStories: Bool
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var selectedVideoURL: URL?
    @State private var isVideo = false
    @State private var isProcessing = false
    @State private var showCamera = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    if isVideo, let videoURL = selectedVideoURL {
                        // Video preview
                        VideoPlayer(player: AVPlayer(url: videoURL))
                            .frame(maxHeight: 500)
                            .cornerRadius(12)
                        
                        Button(action: publishStory) {
                            if isProcessing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                            } else {
                                Text("Share to Story")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                            }
                        }
                        .background(
                            LinearGradient(
                                colors: [Color.purple, Color.pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .disabled(isProcessing)
                        .padding(.horizontal, 40)
                    } else if let imageData = selectedImageData,
                       let uiImage = UIImage(data: imageData) {
                        // Preview
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 500)
                            .cornerRadius(12)
                        
                        Button(action: publishStory) {
                            if isProcessing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                            } else {
                                Text("Share to Story")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                            }
                        }
                        .background(
                            LinearGradient(
                                colors: [Color.purple, Color.pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .disabled(isProcessing)
                        .padding(.horizontal, 40)
                    } else {
                        // Auto-launch camera
                        Color.clear
                            .onAppear {
                                showCamera = true
                            }
                    }
                }
                .padding()
            }
            .navigationTitle("Create Story")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    // Try loading as image first
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        // Check if it's an image
                        if let _ = UIImage(data: data) {
                            selectedImageData = data
                            isVideo = false
                            selectedVideoURL = nil
                        }
                    } else if let movie = try? await newItem?.loadTransferable(type: Movie.self) {
                        // It's a video
                        selectedVideoURL = movie.url
                        isVideo = true
                        selectedImageData = nil
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView(shouldReloadStories: $shouldReloadStories)
                .environmentObject(authManager)
        }
    }
    
    private func publishStory() {
        guard let currentUser = authManager.currentUser else {
            return
        }
        
        isProcessing = true
        
        var mediaUrl = ""
        
        if isVideo, let videoURL = selectedVideoURL {
            // For video, store URL path (in production would upload to server)
            mediaUrl = "video://" + videoURL.absoluteString
        } else if let imageData = selectedImageData {
            // Resize image to reduce storage size
            if let uiImage = UIImage(data: imageData),
               let resizedImage = uiImage.resized(to: CGSize(width: 1080, height: 1920)),
               let compressedData = resizedImage.jpegData(compressionQuality: 0.7) {
                mediaUrl = "data:image/jpeg;base64," + compressedData.base64EncodedString()
            } else {
                mediaUrl = "data:image/jpeg;base64," + imageData.base64EncodedString()
            }
        } else {
            isProcessing = false
            return
        }
        
        let story = Story(
            id: UUID(),
            userId: currentUser.id,
            imageUrl: mediaUrl,
            timestamp: Date(),
            viewedBy: [],  // No one has viewed yet
            reaction: nil,
            replies: [],
            viewerIds: [],
            caption: nil
        )
        
        StoryStorage.shared.addStory(story, for: currentUser.id)
        
        // Trigger reload
        shouldReloadStories = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            HapticManager.shared.notification(type: .success)
            dismiss()
        }
    }
}

// Video transferable type
struct Movie: Transferable {
    let url: URL
    
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let copy = URL.documentsDirectory.appending(path: "movie-\(UUID().uuidString).mov")
            try FileManager.default.copyItem(at: received.file, to: copy)
            return Self(url: copy)
        }
    }
}

// UIImage extension for resizing
extension UIImage {
    func resized(to targetSize: CGSize) -> UIImage? {
        let size = self.size
        
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        
        let scaleFactor = min(widthRatio, heightRatio)
        
        let scaledSize = CGSize(
            width: size.width * scaleFactor,
            height: size.height * scaleFactor
        )
        
        let renderer = UIGraphicsImageRenderer(size: scaledSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: scaledSize))
        }
    }
    
    func cropToAspectRatio(_ aspectRatio: CGFloat) -> UIImage? {
        let size = self.size
        let currentRatio = size.width / size.height
        
        var cropRect: CGRect
        
        if currentRatio > aspectRatio {
            // Image is wider, crop width
            let newWidth = size.height * aspectRatio
            let xOffset = (size.width - newWidth) / 2
            cropRect = CGRect(x: xOffset, y: 0, width: newWidth, height: size.height)
        } else {
            // Image is taller, crop height
            let newHeight = size.width / aspectRatio
            let yOffset = (size.height - newHeight) / 2
            cropRect = CGRect(x: 0, y: yOffset, width: size.width, height: newHeight)
        }
        
        guard let cgImage = self.cgImage?.cropping(to: cropRect) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage, scale: self.scale, orientation: self.imageOrientation)
    }
}
