//
//  CameraView.swift
//  InstaRipoff
//
//  Created on 23/10/2025.
//

import SwiftUI
import AVFoundation

struct CameraView: View {
    @StateObject private var cameraManager = CameraManager()
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    @Binding var shouldReloadStories: Bool
    
    @State private var isPhotoMode = true
    @State private var recordingDuration: TimeInterval = 0
    @State private var recordingTimer: Timer?
    
    var body: some View {
        ZStack {
            // Camera Preview
            if cameraManager.permissionGranted {
                CameraPreviewView(session: cameraManager.captureSession)
                    .ignoresSafeArea()
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("Camera access required")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    if let error = cameraManager.error {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                    
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .foregroundColor(.blue)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
            }
            
            // Camera Controls Overlay
            VStack {
                // Top controls
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Button(action: { cameraManager.toggleFlash() }) {
                        Image(systemName: flashIcon)
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 50)
                
                Spacer()
                
                // Bottom controls
                VStack(spacing: 20) {
                    // Mode selector - Instagram-inspired design
                    HStack(spacing: 12) {
                        Button(action: { isPhotoMode = true }) {
                            HStack(spacing: 8) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Photo")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundColor(isPhotoMode ? .white : .white.opacity(0.6))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                isPhotoMode ?
                                Color.white.opacity(0.2) :
                                Color.clear
                            )
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(isPhotoMode ? Color.white.opacity(0.3) : Color.clear, lineWidth: 1)
                            )
                        }
                        
                        Button(action: { isPhotoMode = false }) {
                            HStack(spacing: 8) {
                                Image(systemName: "video.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Video")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundColor(!isPhotoMode ? .white : .white.opacity(0.6))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                !isPhotoMode ?
                                Color.white.opacity(0.2) :
                                Color.clear
                            )
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(!isPhotoMode ? Color.white.opacity(0.3) : Color.clear, lineWidth: 1)
                            )
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    
                    // Recording duration
                    if cameraManager.isRecording {
                        Text(formatDuration(recordingDuration))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.red)
                    }
                    
                    // Capture controls
                    HStack(spacing: 30) {
                        // Switch camera button - disabled during recording
                        Button(action: {
                            cameraManager.switchCamera()
                        }) {
                            Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                                .opacity(cameraManager.isRecording && !isPhotoMode ? 0.4 : 1.0)
                        }
                        .disabled(cameraManager.isRecording && !isPhotoMode)
                        
                        // Capture button
                        if isPhotoMode {
                            Button(action: {
                                cameraManager.capturePhoto()
                            }) {
                                ZStack {
                                    Circle()
                                        .strokeBorder(Color.white, lineWidth: 4)
                                        .frame(width: 70, height: 70)
                                    
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 60, height: 60)
                                }
                            }
                        } else {
                            Button(action: {
                                if cameraManager.isRecording {
                                    cameraManager.stopRecording()
                                    recordingTimer?.invalidate()
                                } else {
                                    cameraManager.startRecording()
                                    startRecordingTimer()
                                }
                            }) {
                                ZStack {
                                    Circle()
                                        .strokeBorder(Color.white, lineWidth: 4)
                                        .frame(width: 70, height: 70)
                                    
                                    if cameraManager.isRecording {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.red)
                                            .frame(width: 30, height: 30)
                                    } else {
                                        Circle()
                                            .fill(Color.red)
                                            .frame(width: 60, height: 60)
                                    }
                                }
                            }
                        }
                        
                        // Gallery button (placeholder)
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: 60, height: 60)
                    }
                }
                .padding(.bottom, 40)
            }
            
            // Preview captured photo/video
            if let image = cameraManager.capturedImage {
                let resizedImage = image.resized(to: CGSize(width: 1080, height: 1920)) ?? image
                StoryEditorView(
                    image: resizedImage,
                    onDiscard: {
                        cameraManager.capturedImage = nil
                    },
                    onPost: { editedImage, caption in
                        postStory(image: editedImage, caption: caption)
                    }
                )
                .transition(.move(edge: .bottom))
            } else if let videoURL = cameraManager.capturedVideoURL {
                VideoEditorView(
                    videoURL: videoURL,
                    onDiscard: {
                        cameraManager.capturedVideoURL = nil
                    },
                    onPost: { url in
                        postStory(videoURL: url)
                    }
                )
                .transition(.move(edge: .bottom))
            }
        }
        .onAppear {
            cameraManager.startSession()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
    }
    
    private var flashIcon: String {
        switch cameraManager.flashMode {
        case .off:
            return "bolt.slash.fill"
        case .on:
            return "bolt.fill"
        case .auto:
            return "bolt.badge.automatic.fill"
        @unknown default:
            return "bolt.slash.fill"
        }
    }
    
    private func startRecordingTimer() {
        recordingDuration = 0
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            recordingDuration += 0.1
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let deciseconds = Int((duration.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%d:%02d.%d", minutes, seconds, deciseconds)
    }
    
    private func postStory(image: UIImage, caption: String?) {
        guard let currentUser = authManager.currentUser else { return }
        
        // Crop to 9:16 aspect ratio and resize
        if let croppedImage = image.cropToAspectRatio(9.0/16.0),
           let resizedImage = croppedImage.resized(to: CGSize(width: 1080, height: 1920)),
           let compressedData = resizedImage.jpegData(compressionQuality: 0.7) {
            let base64String = "data:image/jpeg;base64," + compressedData.base64EncodedString()
            
            let story = Story(
                id: UUID(),
                userId: currentUser.id,
                imageUrl: base64String,
                timestamp: Date(),
                viewedBy: [],  // No one has viewed yet
                reaction: nil,
                replies: [],
                viewerIds: [],
                caption: caption
            )
            
            StoryStorage.shared.addStory(story, for: currentUser.id)
            shouldReloadStories = true
            HapticManager.shared.notification(type: .success)
            dismiss()
        }
    }
    
    private func postStory(videoURL: URL) {
        guard let currentUser = authManager.currentUser else { return }
        
        let mediaUrl = "video://" + videoURL.absoluteString
        
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
        shouldReloadStories = true
        HapticManager.shared.notification(type: .success)
        dismiss()
    }
}

// Camera Preview using UIViewRepresentable
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession?
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        
        guard let session = session else { return view }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        
        context.coordinator.previewLayer = previewLayer
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.previewLayer?.frame = uiView.bounds
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}
