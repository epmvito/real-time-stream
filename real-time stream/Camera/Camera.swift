import UIKit
import AVFoundation

final class Camera: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    //MARK: - Variables and Properties
    
    private let captureSession = AVCaptureSession()
    private weak var gpuOperator: GPUOperator?
    
    init(gpuOperator: GPUOperator?) {
        self.gpuOperator = gpuOperator
        super.init()
        
        self.gpuOperator?.graphicsEncoder = try! .init(device:  gpuOperator!.device, library: gpuOperator!.frameworkBundleLibrary)
    }
    
    //MARK: - Class Methods
    
    func requestCameraAccessAndConfigure(completion: @escaping () -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard granted else { return }
            self?.configureCaptureSession()
            completion()
        }
    }
    
    private func configureCaptureSession() {
        guard let device = AVCaptureDevice.default(for: .video),
              let captureInput = try? AVCaptureDeviceInput(device: device),
              captureSession.canAddInput(captureInput)
        else { return }
        
        setupSessionInput(captureInput)
        setupSessionOutput()
        captureSession.commitConfiguration()
    }
    
    private func setupSessionInput(_ input: AVCaptureDeviceInput) {
        captureSession.beginConfiguration()
        captureSession.addInput(input)
    }
    
    private func setupSessionOutput() {
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        output.setSampleBufferDelegate(self, queue: .init(label: "com.realTimeStream.cameraQueue"))
        guard captureSession.canAddOutput(output) else { return }
        captureSession.addOutput(output)
    }
    
    func start() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
        }
    }
    
    func stop() {
        self.captureSession.stopRunning()
    }
    
    func getCurrentFrameDuration() -> Double? {
        guard let videoInput = captureSession.inputs.first as? AVCaptureDeviceInput else {
            return nil
        }
        
        let videoDevice = videoInput.device
        let activeFormat = videoDevice.activeFormat
        return activeFormat.videoSupportedFrameRateRanges.first?.maxFrameRate
    }
}

extension Camera {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard connection.videoOrientation == .portrait else {
            connection.videoOrientation = .portrait
            return
        }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let _ = gpuOperator?.compute(pixelBuffer: pixelBuffer)
    }
}

