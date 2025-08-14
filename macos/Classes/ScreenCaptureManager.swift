import FlutterMacOS
import ScreenCaptureKit
import CoreImage
import Metal
import SDWebImage
import SDWebImageWebPCoder

@available(macOS 15.0, *)
class ScreenCaptureManager: NSObject, SCStreamDelegate, SCStreamOutput {
    private weak var plugin: FlutterScreenSharePlugin?
    private var frameEncoder: FrameEncoder?
    private var stream: SCStream?
    private var lastFrameTime: CFTimeInterval = 0
    private var frameInterval: CFTimeInterval = 1.0 / 24.0
    private var frameCount: Int = 0
    private var encodingType: String = "webp"
    private var quality: Float = 0.8
    private let webpEncoder = SDImageWebPCoder.shared
    private let processingQueue = DispatchQueue(label: "com.screen.share.processing", qos: .userInteractive, attributes: .concurrent)
    
    init(plugin: FlutterScreenSharePlugin) {
        self.plugin = plugin
        super.init()
    }
    
    private func setupCaptureTexture(width: Int, height: Int) -> Int64? {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        textureDescriptor.storageMode = .shared
        
        return plugin?.setupTexture(descriptor: textureDescriptor)
    }
    
    public func startCapture(_ result: @escaping FlutterResult, source: [String: Any]?) {
        startScreenCapture(result, source: source)
    }
    
    func stopCapture(_ result: @escaping FlutterResult) {
        guard let stream = stream else {
            result(nil)
            return
        }
        
        Task {
            do {
                try await stream.stopCapture()
                self.stream = nil
                plugin?.cleanupTexture()
                result(nil)
            } catch {
                result(FlutterError(code: "STOP_ERROR", message: error.localizedDescription, details: nil))
            }
        }
    }
    
    private func startScreenCapture(_ result: @escaping FlutterResult, source: [String: Any]?) {
        guard let plugin = plugin,
              let ciContext = plugin.ciContext else {
            result(FlutterError(code: "INIT_ERROR", message: "Plugin or CIContext not initialized", details: nil))
            return
        }
        
        let sourceConfig = source?["source"] as? [String: Any]
        let encodingOptions = source?["options"] as? [String: Any] ?? [:]
        
        encodingType = encodingOptions["type"] as? String ?? "webp"
        let fps = encodingOptions["fps"] as? Int ?? 24
        frameInterval = 1.0 / Double(fps)
        quality = Float(encodingOptions["quality"] as? Double ?? 0.8)
        
        frameEncoder = FrameEncoder(
            quality: quality,
            ciContext: ciContext,
            encodingType: encodingType
        )
        
        Task {
            do {
                let content = try await SCShareableContent.current
                var chosenFilter: SCContentFilter?
                var configWidth: Int = 0
                var configHeight: Int = 0
                
                if let sourceConfig = sourceConfig, let type = sourceConfig["type"] as? String {
                    if type == "display" {
                        let maybeDisplayID: UInt32? = {
                            if let idInt = sourceConfig["id"] as? Int { return UInt32(idInt) }
                            if let idUInt = sourceConfig["id"] as? UInt32 { return idUInt }
                            return nil
                        }()
                        guard let displayID = maybeDisplayID,
                              let selectedDisplay = content.displays.first(where: { $0.displayID == displayID }) else {
                            result(FlutterError(code: "NO_DISPLAY", message: "Selected display not found", details: nil))
                            return
                        }
                        chosenFilter = SCContentFilter(display: selectedDisplay, excludingWindows: [])
                        configWidth = Int(selectedDisplay.width)
                        configHeight = Int(selectedDisplay.height)
                    }
                } else {
                    guard let defaultDisplay = content.displays.first else {
                        result(FlutterError(code: "NO_DISPLAY", message: "No display found", details: nil))
                        return
                    }
                    chosenFilter = SCContentFilter(display: defaultDisplay, excludingWindows: [])
                    configWidth = Int(defaultDisplay.width)
                    configHeight = Int(defaultDisplay.height)
                }
                
                let config = SCStreamConfiguration()
                config.width = configWidth
                config.height = configHeight
                config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(fps))
                config.pixelFormat = kCVPixelFormatType_32BGRA
                config.queueDepth = 8
                config.scalesToFit = false
                config.showsCursor = true
                
                guard let validFilter = chosenFilter else {
                    result(FlutterError(code: "FILTER_ERROR", message: "Unable to create content filter", details: nil))
                    return
                }
                
                let textureId = setupCaptureTexture(width: Int(configWidth), height: Int(configHeight))
                print("Registered texture with ID: \(String(describing: textureId))")
                
                let stream = SCStream(filter: validFilter, configuration: config, delegate: self)
                try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .global())
                try await stream.startCapture()
                
                self.stream = stream
                
                result(["textureId": textureId ?? -1])
            } catch {
                result(FlutterError(code: "CAPTURE_ERROR", message: error.localizedDescription, details: nil))
            }
        }
    }
    
    public func stream(_ stream: SCStream, didStopWithError error: Error) {
        DispatchQueue.main.async {
            self.plugin?.streamOutput?(FlutterError(code: "STREAM_ERROR", message: error.localizedDescription, details: nil))
        }
    }
    
    public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }
        
        let currentTime = CACurrentMediaTime()
        guard (currentTime - lastFrameTime) >= frameInterval else { return }
        lastFrameTime = currentTime
        
        guard let imageBuffer = sampleBuffer.imageBuffer else { return }
        
        guard let plugin = self.plugin,
              let texture = plugin.metalTexture else { return }
        
        CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
        let region = MTLRegionMake2D(0, 0, CVPixelBufferGetWidth(imageBuffer), CVPixelBufferGetHeight(imageBuffer))
        texture.replace(region: region,
                        mipmapLevel: 0,
                        withBytes: CVPixelBufferGetBaseAddress(imageBuffer)!,
                        bytesPerRow: CVPixelBufferGetBytesPerRow(imageBuffer))
        CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly)
        
        DispatchQueue.main.async { [weak self] in
            guard let textureId = self?.plugin?.textureId else { return }
            self?.plugin?.textureRegistry?.textureFrameAvailable(textureId)
        }
        
        frameCount += 1
        guard frameCount % 2 == 0 else { return }
        
        processingQueue.async { [weak self] in
            guard let self = self,
                  let plugin = self.plugin,
                  let imageBuffer = sampleBuffer.imageBuffer,
                  let encodedData = self.frameEncoder?.encode(imageBuffer) else { return }
            
            DispatchQueue.main.async {
                plugin.streamOutput?(FlutterStandardTypedData(bytes: encodedData))
            }
        }
    }
}
