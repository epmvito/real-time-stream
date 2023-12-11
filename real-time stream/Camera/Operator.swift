import Metal
import UIKit

typealias GPUOperatorDrawable = CAMetalDrawable

enum OperationError: Error {
    case failedToConfigure
    case libraryLoadFailed
}

//MARK: - GPUOperator

class GPUOperator {
    
    //MARK: - Variables and Properties
    
    var kernelEncoder: AnyKernelEncoder
    var graphicsEncoder: GraphicsEncoder
    var pixelBufferProcessor: PixelBufferProcessor
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let mainBundleLibrary: MTLLibrary
    let frameworkBundleLibrary: MTLLibrary
    var destinationTexture: MTLTexture!
    var sourceTextures: [MTLTexture] = []
    var videoRecorder: VideoRecorder?
    var ciContext: CIContext?
    
    //MARK: - Class Methods
    
    init() throws {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            throw OperationError.failedToConfigure
        }
        
        do {
            let frameworkBundleLibrary = try device.makeDefaultLibrary(bundle: .init(for: GPUOperator.self))
            self.device = device
            self.frameworkBundleLibrary = frameworkBundleLibrary
            self.mainBundleLibrary = try device.makeDefaultLibrary(bundle: .main)
            self.ciContext = CIContext(mtlDevice: device)
            kernelEncoder = try PassThroughEncoder(device: device, library: frameworkBundleLibrary)
            graphicsEncoder = try .init(device: device, library: frameworkBundleLibrary)
            pixelBufferProcessor = .init(device: device, pixelFormat: graphicsEncoder.pixelFormat)
            self.commandQueue = commandQueue
        } catch {
            throw OperationError.libraryLoadFailed
        }
    }
    

    func commit(drawable: GPUOperatorDrawable) {
        let commandBuffer = commandQueue.makeCommandBuffer()
        
        if destinationTexture == nil {
            destinationTexture = makeEmptyTexture(width: drawable.texture.width, height: drawable.texture.height)
        }
    
        kernelEncoder.encode(buffer: commandBuffer, destinationTexture: destinationTexture, sourceTextures: sourceTextures)
        graphicsEncoder.encode(commandBuffer: commandBuffer, targetDrawable: drawable, presentingTexture: destinationTexture)
        
        commandBuffer?.present(drawable)
        commandBuffer?.commit()
        commandBuffer?.waitUntilCompleted()
        addToVideo(texture: drawable.texture)
    }
    
    func addToVideo(texture: MTLTexture) {
        guard let videoRecorder = self.videoRecorder, let context = self.ciContext else {return}
        
        videoRecorder.recordingQueue.async {
            let width = texture.width
            let height = texture.height
            
            var pixelBuffer: CVPixelBuffer?
            let attributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferMetalCompatibilityKey as String: true,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height
            ]
            
            let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, attributes as CFDictionary, &pixelBuffer)
            guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
                return
            }
            
            guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {return}
            let ciImageOptions: [CIImageOption: Any] = [.colorSpace: colorSpace]
            
            guard let ciImage = CIImage(mtlTexture: texture, options: ciImageOptions)?.oriented(.downMirrored) else {return}
            
            context.render(ciImage, to: buffer)
            
            videoRecorder.addFrame(pixelBuffer: buffer)
        }
    }
    
    func compute(pixelBuffer: CVPixelBuffer) -> MTLTexture? {
        guard let bufferTexture = pixelBufferProcessor.makeTexture(imageBuffer: pixelBuffer) else { return nil }
        
        destinationTexture = makeEmptyTexture(width: bufferTexture.width, height: bufferTexture.height)
        sourceTextures = [bufferTexture]
        return bufferTexture
    }
    
    func makeEmptyTexture(width: Int, height: Int) -> MTLTexture? {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: graphicsEncoder.pixelFormat,
            width: width,
            height: height,
            mipmapped: false
        )
        
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        return device.makeTexture(descriptor: textureDescriptor)
    }
}
