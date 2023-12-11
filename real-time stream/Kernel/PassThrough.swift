import Metal

//MARK: - PassThroughKernel

final class PassThroughKernel: Kernel {
    static let functionName: String = "pass_through"
}

//MARK: - PassThroughEncoder

final class PassThroughEncoder: KernelEncoder<PassThroughKernel> {
    
    convenience init(device: MTLDevice, library: MTLLibrary) throws {
        try self.init(device: device, library: library, kernel: .init())
    }
}
