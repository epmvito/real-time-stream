import Foundation
import AVFoundation

class VideoRecorder {
    
    //MARK: - Variables and Properties
    
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var videoAssetWriterAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var isRecording = false
    private var currentTime: CMTime = .zero
    
    private var frameDuration = CMTimeMake(value: 1, timescale: 60)
    
    let recordingQueue = DispatchQueue(label: "com.realTimeStream.recordingQueue")
    
    var fileUrl: URL?
    
    //MARK: - Class Methods
    
    init(frameRate: Double) {
        self.frameDuration = CMTimeMake(value: 1, timescale: Int32(1/frameRate))
    }
    
    func startRecording(size: CGSize, completion: @escaping () -> Void) {
        recordingQueue.async {
            self.fileUrl = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("\(UUID().uuidString)_realTimeStream.mp4")
            
            self.assetWriter = try? AVAssetWriter(url: self.fileUrl!, fileType: .mp4)
            
            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: size.width,
                AVVideoHeightKey: size.height
            ]
            
            self.videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            self.assetWriter?.add(self.videoInput!)
            
            self.videoAssetWriterAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: self.videoInput!)
            
            self.isRecording = true
            self.currentTime = .zero
            self.assetWriter?.startWriting()
            self.assetWriter?.startSession(atSourceTime: .zero)
            completion()
        }
    }
    
    func addFrame(pixelBuffer: CVPixelBuffer) {
        recordingQueue.async {
            if self.isRecording && self.videoInput?.isReadyForMoreMediaData == true {
                self.videoAssetWriterAdaptor?.append(pixelBuffer, withPresentationTime: self.currentTime)
                self.currentTime = CMTimeAdd(self.currentTime, self.frameDuration)
            }
        }
    }
    
    func stopRecording(completion: @escaping () -> Void) {
        recordingQueue.async {
            self.isRecording = false
            self.videoInput?.markAsFinished()
            self.currentTime = .zero
            self.assetWriter?.finishWriting(completionHandler: completion)
        }
    }
}
