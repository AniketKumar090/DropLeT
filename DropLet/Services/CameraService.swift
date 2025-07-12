import AVFoundation
import Combine
import SwiftUI

class CameraService: ObservableObject {
    @Published var isSessionConfigured = false
    let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var videoDeviceInput: AVCaptureDeviceInput?
    
    init() {
        // Configure session on a background thread for better performance
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.configureSession()
        }
    }
    
    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .high
        
        // Use the default video device for better initialization speed
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                       for: .video,
                                                       position: .back) else {
            session.commitConfiguration()
            return
        }
        
        do {
            videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            guard let videoInput = videoDeviceInput,
                  session.canAddInput(videoInput) else {
                session.commitConfiguration()
                return
            }
            session.addInput(videoInput)
            DispatchQueue.main.async { [weak self] in
                self?.isSessionConfigured = true
            }
        } catch {
            print("Error setting up video input: \(error.localizedDescription)")
            session.commitConfiguration()
            return
        }
        
        session.commitConfiguration()
    }
    
    func startCamera() {
        guard !session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }
    
    func stopCamera() {
        guard session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.stopRunning()
        }
    }
}
