import Metal
import UIKit

/**
 PixelBufferProcessor is used to convert image buffers to MTLTextures
 */

open class PixelBufferProcessor {
    
    //MARK: - Variables and Properties
    
    var textureCache: CVMetalTextureCache?
    private let pixelFormat: MTLPixelFormat
    
    //MARK: - Class Methods
    
    init(device: MTLDevice, pixelFormat: MTLPixelFormat) {
        self.pixelFormat = pixelFormat
        var newTextureCache: CVMetalTextureCache?
        let error = CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &newTextureCache)
        if error == kCVReturnSuccess {
            textureCache = newTextureCache
        } else {
            print("Error: Failed to create texture cache: \(error.description)")
        }
    }
    
    open func makeTexture(imageBuffer: CVPixelBuffer) -> MTLTexture? {
        guard let cache = textureCache else { return nil }
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        
        var imageTexture: CVMetalTexture?
        let result =  CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            cache,
            imageBuffer,
            nil,
            pixelFormat,
            width,
            height,
            0,
            &imageTexture
        )
        
        guard result == kCVReturnSuccess,let imageTexture, let metalTexture = CVMetalTextureGetTexture(imageTexture) else {
            return nil
        }
        
        return metalTexture
    }
}
