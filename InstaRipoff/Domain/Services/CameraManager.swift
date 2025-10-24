//
//  CameraManager.swift
//  InstaRipoff
//
//  Created on 23/10/2025.
//

import AVFoundation
import SwiftUI
import Photos

class CameraManager: NSObject, ObservableObject {
    @Published var capturedImage: UIImage?
    @Published var capturedVideoURL: URL?
    @Published var isRecording = false
    @Published var isFrontCamera = false
    @Published var flashMode: AVCaptureDevice.FlashMode = .off
    @Published var error: String?
    @Published var permissionGranted = false
    
    var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var videoOutput: AVCaptureMovieFileOutput?
    private var currentCamera: AVCaptureDevice?
    private var videoDelegate: VideoRecordingDelegate?
    
    override init() {
        super.init()
        checkPermissions()
    }
    
    func checkPermissions() {
        // Check camera permission
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            checkAudioPermission()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.checkAudioPermission()
                    } else {
                        self?.permissionGranted = false
                        self?.error = "Camera access denied. Please enable in Settings."
                    }
                }
            }
        case .denied, .restricted:
            permissionGranted = false
            error = "Camera access denied. Please enable in Settings."
        @unknown default:
            permissionGranted = false
        }
    }
    
    private func checkAudioPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            permissionGranted = true
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.permissionGranted = true // Allow camera even if mic denied
                    self?.setupCamera()
                    if !granted {
                        self?.error = "Microphone access denied. Videos will have no sound."
                    }
                }
            }
        case .denied, .restricted:
            permissionGranted = true // Allow camera even if mic denied
            setupCamera()
            error = "Microphone access denied. Videos will have no sound."
        @unknown default:
            permissionGranted = true
            setupCamera()
        }
    }
    
    func setupCamera() {
        captureSession = AVCaptureSession()
        guard let captureSession = captureSession else { return }
        
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .photo
        
        // Setup camera input
        guard let camera = getCamera(front: isFrontCamera) else {
            error = "No camera available"
            return
        }
        
        currentCamera = camera
        
        do {
            let videoInput = try AVCaptureDeviceInput(device: camera)
            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
            }
            
            // Add audio input for video recording
            if let audioDevice = AVCaptureDevice.default(for: .audio) {
                let audioInput = try AVCaptureDeviceInput(device: audioDevice)
                if captureSession.canAddInput(audioInput) {
                    captureSession.addInput(audioInput)
                }
            }
            
            // Photo output
            let photoOut = AVCapturePhotoOutput()
            if captureSession.canAddOutput(photoOut) {
                captureSession.addOutput(photoOut)
                photoOutput = photoOut
            }
            
            // Video output
            let videoOut = AVCaptureMovieFileOutput()
            if captureSession.canAddOutput(videoOut) {
                captureSession.addOutput(videoOut)
                videoOutput = videoOut
            }
            
            captureSession.commitConfiguration()
        } catch {
            self.error = "Failed to setup camera: \(error.localizedDescription)"
        }
    }
    
    func startSession() {
        guard let captureSession = captureSession, !captureSession.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            captureSession.startRunning()
        }
    }
    
    func stopSession() {
        guard let captureSession = captureSession, captureSession.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            captureSession.stopRunning()
        }
    }
    
    func capturePhoto() {
        guard let photoOutput = photoOutput else { return }
        
        let settings = AVCapturePhotoSettings()
        settings.flashMode = flashMode
        
        photoOutput.capturePhoto(with: settings, delegate: self)
        HapticManager.shared.notification(type: .success)
    }
    
    func startRecording() {
        guard let videoOutput = videoOutput, !isRecording else { return }
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")
        
        videoDelegate = VideoRecordingDelegate { [weak self] url in
            self?.capturedVideoURL = url
            self?.isRecording = false
        }
        
        videoOutput.startRecording(to: tempURL, recordingDelegate: videoDelegate!)
        isRecording = true
        HapticManager.shared.impact(style: .heavy)
    }
    
    func stopRecording() {
        guard let videoOutput = videoOutput, isRecording else { return }
        videoOutput.stopRecording()
        HapticManager.shared.impact(style: .heavy)
    }
    
    func switchCamera() {
        isFrontCamera.toggle()
        
        guard let captureSession = captureSession else { return }
        captureSession.beginConfiguration()
        
        // Remove only video inputs (keep audio)
        captureSession.inputs.forEach { input in
            if let deviceInput = input as? AVCaptureDeviceInput,
               deviceInput.device.hasMediaType(.video) {
                captureSession.removeInput(input)
            }
        }
        
        // Add new camera
        if let camera = getCamera(front: isFrontCamera) {
            do {
                let input = try AVCaptureDeviceInput(device: camera)
                if captureSession.canAddInput(input) {
                    captureSession.addInput(input)
                    currentCamera = camera
                }
            } catch {
                // Handle camera switch error silently
            }
        }
        
        captureSession.commitConfiguration()
        HapticManager.shared.impact(style: .light)
    }
    
    func toggleFlash() {
        switch flashMode {
        case .off:
            flashMode = .on
        case .on:
            flashMode = .auto
        case .auto:
            flashMode = .off
        @unknown default:
            flashMode = .off
        }
        HapticManager.shared.impact(style: .light)
    }
    
    private func getCamera(front: Bool) -> AVCaptureDevice? {
        let deviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInWideAngleCamera,
            .builtInDualCamera,
            .builtInTrueDepthCamera
        ]
        
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: front ? .front : .back
        )
        
        return discoverySession.devices.first
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            self.error = "Photo capture failed: \(error.localizedDescription)"
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            self.error = "Failed to process photo"
            return
        }
        
        DispatchQueue.main.async {
            self.capturedImage = image
        }
    }
}

// MARK: - Video Recording Delegate
class VideoRecordingDelegate: NSObject, AVCaptureFileOutputRecordingDelegate {
    let completion: (URL) -> Void
    
    init(completion: @escaping (URL) -> Void) {
        self.completion = completion
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if error != nil {
            // Handle video recording error silently
            return
        }
        
        completion(outputFileURL)
    }
}
