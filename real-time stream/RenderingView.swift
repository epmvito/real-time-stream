import UIKit
import Metal
import MetalKit

/**
Rendering View:- Used to render and display the camera feed on screen
 */

final class RenderingView: UIView {
    
    //MARK: - Variables and Properties
    
     var gpuOperator: GPUOperator? {
        didSet {
            guard let gpu = gpuOperator else { return }
            metalLayer.device = gpu.device
            metalLayer.pixelFormat = gpu.graphicsEncoder.pixelFormat
            metalLayer.framebufferOnly = false
            metalLayer.contentsScale = isRoughnessAcceptable ? 1 : UIScreen.main.nativeScale
        }
    }
    
     var isRoughnessAcceptable: Bool = false {
        didSet {
            metalLayer.contentsScale = isRoughnessAcceptable ? 1 : UIScreen.main.nativeScale
        }
    }
    
    var metalLayer: CAMetalLayer {
        return layer as! CAMetalLayer
    }
    
    private var link: CADisplayLink?
    
    public override class var layerClass: AnyClass {
        return CAMetalLayer.self
    }
    
    //MARK: - Class Methods
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configure()
    }
    
    deinit {
        stop()
    }
    
    private func configure() {
        backgroundColor = .clear
    }
    
    public func run() {
        link = CADisplayLink(target: self, selector: #selector(render))
        link?.add(to: .main, forMode: .common)
    }
    
    public func stop() {
        link?.invalidate()
        link = nil
    }
    
    @objc func render() {
        autoreleasepool {
            guard let drawable = metalLayer.nextDrawable() else { return }
            gpuOperator?.commit(drawable: drawable)
        }
    }
}
