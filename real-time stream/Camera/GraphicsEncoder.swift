import Metal
import simd
import UIKit

enum FragmentShaders: String {
    case vhs = "vhs2"
    case `default` = "displayBackTexture"
}

enum ScalingMode: Int, CaseIterable {
    case scaledToFill
    case aspectFill
    case aspectFit
    
    static let mapper: [ScalingMode: String] = [
        .scaledToFill: "ScaledToFill",
        .aspectFill: "AspectFill",
        .aspectFit: "AspectFit"
    ]
    
    var label: String {
        return ScalingMode.mapper[self]!
    }
}

struct AspectRatioData {
    var sourceAspectRatio: SIMD2<Float>
    var destinationAspectRatio: SIMD2<Float>
}

class GraphicsEncoder {
    
    //MARK: - Variables and Properties
    
    var renderPipelineState: MTLRenderPipelineState?
    let pixelFormat: MTLPixelFormat
    let device: MTLDevice
    let library: MTLLibrary
    
    var fragmentFunctionName: FragmentShaders {
        didSet {
            try? updatePipelineState()
        }
    }
    
    var scalingMode: ScalingMode
    var currentTime: Float = 0
    
    init(device: MTLDevice, library: MTLLibrary, pixelFormat: MTLPixelFormat = .bgra8Unorm) throws {
        self.device = device
        self.library = library
        self.pixelFormat = pixelFormat
        self.fragmentFunctionName = .default
        self.scalingMode = ScalingMode.scaledToFill
        try self.updatePipelineState()
    }
    
    deinit {
        currentTime = 0
    }
    
    private func updatePipelineState() throws {
        let fragmentFunction = library.makeFunction(name: fragmentFunctionName.rawValue)
        let vertexFunction = library.makeFunction(name: "scalingVertex")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat
        
        self.renderPipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }
    
    
    func encode(commandBuffer: MTLCommandBuffer?, targetDrawable: CAMetalDrawable, presentingTexture: MTLTexture) {
        currentTime += 0.017
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = targetDrawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = .init(red: 0, green: 0, blue: 0, alpha: 1)
        let renderEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        renderEncoder?.setRenderPipelineState(renderPipelineState!)
        renderEncoder?.setFragmentTexture(presentingTexture, index: 0)
        
        var aspectRatioData = AspectRatioData(sourceAspectRatio: SIMD2<Float>(Float(presentingTexture.width), Float(presentingTexture.height)), destinationAspectRatio: SIMD2<Float>(Float(targetDrawable.texture.width), Float(targetDrawable.texture.height)))
        if let buffer = device.makeBuffer(bytes: &aspectRatioData, length: MemoryLayout<AspectRatioData>.size, options: []) {
            renderEncoder?.setVertexBuffer(buffer, offset: 0, index: 0)
        }
        var scalingMode = self.scalingMode.rawValue
        if let buffer2 = device.makeBuffer(bytes: &scalingMode, length: MemoryLayout<Int>.size, options: []) {
            renderEncoder?.setVertexBuffer(buffer2, offset: 0, index: 1)
        }
        
        if let buffer3 = device.makeBuffer(bytes: &currentTime, length: MemoryLayout<Float>.size, options: []) {
            renderEncoder?.setFragmentBuffer(buffer3, offset: 0, index: 1)
        }
        
        var iResolution = SIMD2<Float>(Float(targetDrawable.texture.width), Float(targetDrawable.texture.height))
        if let buffer4 = device.makeBuffer(bytes: &iResolution, length: MemoryLayout<SIMD2<Float>>.size, options: []) {
            renderEncoder?.setFragmentBuffer(buffer4, offset: 0, index: 0)
        }
        
        renderEncoder?.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: 1)
        renderEncoder?.endEncoding()
        
    }
}
