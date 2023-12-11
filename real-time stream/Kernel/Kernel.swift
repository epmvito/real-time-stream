import Metal

public protocol Kernel {
    static var functionName: String { get }
    func encode(withEncoder encoder: MTLComputeCommandEncoder)
}

public extension Kernel {
    func encode(withEncoder encoder: MTLComputeCommandEncoder) {}
}
