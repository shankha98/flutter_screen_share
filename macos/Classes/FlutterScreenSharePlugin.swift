import FlutterMacOS
import ScreenCaptureKit
import CoreImage
import Metal
import SDWebImage
import SDWebImageWebPCoder

public class FlutterScreenSharePlugin: NSObject, FlutterPlugin {
    internal var streamOutput: FlutterEventSink?
    internal var textureRegistry: FlutterTextureRegistry?
    internal var textureId: Int64?
    internal var metalTexture: MTLTexture?
    private var metalDevice: MTLDevice?
    internal var ciContext: CIContext?
    private var captureManager: ScreenCaptureManager?
    private var audioCaptureManager: AudioCaptureManager?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_screen_share", binaryMessenger: registrar.messenger)
        let eventChannel = FlutterEventChannel(name: "flutter_screen_share/stream", binaryMessenger: registrar.messenger)
        let instance = FlutterScreenSharePlugin()
        instance.textureRegistry = registrar.textures
        instance.metalDevice = MTLCreateSystemDefaultDevice()
        instance.ciContext = CIContext(mtlDevice: instance.metalDevice!)
        registrar.addMethodCallDelegate(instance, channel: channel)
        eventChannel.setStreamHandler(instance)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startCapture":
            startCapture(result, source: call.arguments as? [String: Any])
        case "stopCapture":
            stopCapture(result)
        case "getDisplays":
            getDisplays(result)
        case "getSources":
            getSources(result)
        case "startAudioCapture":
            startAudioCapture(result)
        case "stopAudioCapture":
            stopAudioCapture(result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    func getOwnerName(for windowID: UInt32) -> String? {
        let options: CGWindowListOption = [.optionIncludingWindow]
        
        if let infoList = CGWindowListCopyWindowInfo(options, CGWindowID(windowID)) as? [[String: Any]],
           let info = infoList.first,
           let ownerName = info[kCGWindowOwnerName as String] as? String {
            return ownerName
        }
        return nil
    }
    private func startCapture(_ result: @escaping FlutterResult, source: [String: Any]?) {
        captureManager = ScreenCaptureManager(plugin: self)
        captureManager?.startCapture(result, source: source)
    }
    private func stopCapture(_ result: @escaping FlutterResult) {
        captureManager?.stopCapture(result)
        captureManager = nil
    }
    
    private func startAudioCapture(_ result: @escaping FlutterResult) {
        if #available(macOS 13.0, *) {
            audioCaptureManager = AudioCaptureManager()
            audioCaptureManager?.startAudioCapture { [weak self] captureResult in
                DispatchQueue.main.async {
                    switch captureResult {
                    case .success(let filePath):
                        result(filePath)
                    case .failure(let error):
                        result(FlutterError(code: "AUDIO_CAPTURE_FAILED", message: error.localizedDescription, details: nil))
                    }
                }
            }
        } else {
            result(FlutterError(code: "UNSUPPORTED_VERSION", message: "Audio capture requires macOS 13.0 or later", details: nil))
        }
    }
    
    private func stopAudioCapture(_ result: @escaping FlutterResult) {
        if #available(macOS 13.0, *) {
            audioCaptureManager?.stopAudioCapture { [weak self] stopResult in
                DispatchQueue.main.async {
                    switch stopResult {
                    case .success():
                        result(nil)
                    case .failure(let error):
                        result(FlutterError(code: "AUDIO_STOP_FAILED", message: error.localizedDescription, details: nil))
                    }
                    self?.audioCaptureManager = nil
                }
            }
        } else {
            result(FlutterError(code: "UNSUPPORTED_VERSION", message: "Audio capture requires macOS 13.0 or later", details: nil))
        }
    }
    func setupTexture(descriptor: MTLTextureDescriptor) -> Int64? {
        self.metalTexture = metalDevice?.makeTexture(descriptor: descriptor)
        self.textureId = textureRegistry?.register(self)
        return self.textureId
    }
    
    func cleanupTexture() {
        if let textureId = textureId {
            textureRegistry?.unregisterTexture(textureId)
            self.textureId = nil
        }
        metalTexture = nil
    }
    private func getDisplays(_ result: @escaping FlutterResult) {
        if #available(macOS 12.3, *) {
            Task {
                do {
                    let content = try await SCShareableContent.current
                    let displays = content.displays.map { [
                        "type": "display",
                        "id": $0.displayID,
                        "width": $0.width,
                        "height": $0.height,
                        "name": "Display \($0.displayID)"
                    ] }
                    result(displays)
                } catch {
                    result(FlutterError(code: "DISPLAYS_ERROR", message: error.localizedDescription, details: nil))
                }
            }
        } else {
            // Fallback for older macOS - use CGDisplay APIs
            let activeDisplays = CGDisplayCopyAllDisplayModes(CGMainDisplayID(), nil) as? [CGDisplayMode] ?? []
            let displays = activeDisplays.map { mode -> [String: Any] in
                [
                    "type": "display",
                    "id": CGMainDisplayID(),
                    "width": mode.pixelWidth,
                    "height": mode.pixelHeight,
                    "name": "Display \(CGMainDisplayID())"
                ]
            }
            result(displays)
        }
    }
    
    private func getSources(_ result: @escaping FlutterResult) {
        if #available(macOS 12.3, *) {
            Task {
                do {
                    let content = try await SCShareableContent.current
                    var sources: [[String: Any]] = []
                    
                    for display in content.displays {
                        sources.append([
                            "type": "display",
                            "id": display.displayID,
                            "width": display.width,
                            "height": display.height,
                            "name": "Display \(display.displayID)"
                        ])
                    }
                    
                    for window in content.windows {
                        let ownerName = getOwnerName(for: window.windowID) ?? "Unknown App"
                        sources.append([
                            "type": "window",
                            "id": window.windowID,
                            "name": window.title ?? "Window \(window.windowID)",
                            "owner": ownerName,
                        ])
                    }
                    result(sources)
                } catch {
                    result(FlutterError(code: "SOURCE_ERROR", message: error.localizedDescription, details: nil))
                }
            }
        } else {
            // Fallback for older macOS - only displays supported
            let activeDisplays = CGDisplayCopyAllDisplayModes(CGMainDisplayID(), nil) as? [CGDisplayMode] ?? []
            let sources = activeDisplays.map { mode -> [String: Any] in
                [
                    "type": "display",
                    "id": CGMainDisplayID(),
                    "width": mode.pixelWidth,
                    "height": mode.pixelHeight,
                    "name": "Display \(CGMainDisplayID())"
                ]
            }
            result(sources)
        }
    }
    
}

extension FlutterScreenSharePlugin: FlutterTexture, FlutterStreamHandler {
    public func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        guard let texture = metalTexture else { return nil }
        
        var pixelBuffer: CVPixelBuffer?
        let pixelFormat = kCVPixelFormatType_32BGRA
        let width = texture.width
        let height = texture.height
        
        let attrs = [
            kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary,
            kCVPixelBufferMetalCompatibilityKey: true
        ] as CFDictionary
        
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                         width,
                                         height,
                                         pixelFormat,
                                         attrs,
                                         &pixelBuffer)
        
        guard status == kCVReturnSuccess, let pixelBuffer = pixelBuffer else { return nil }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return nil
        }
        
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let region = MTLRegionMake2D(0, 0, width, height)
        
        texture.getBytes(baseAddress,
                         bytesPerRow: bytesPerRow,
                         from: region,
                         mipmapLevel: 0)
        
        return Unmanaged.passRetained(pixelBuffer)
    }
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        streamOutput = events
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        streamOutput = nil
        return nil
    }
}
@available(macOS 12.3, *)
extension FlutterScreenSharePlugin: SCStreamDelegate {
    public func stream(_ stream: SCStream, didStopWithError error: Error) {
        DispatchQueue.main.async {
            self.streamOutput?(FlutterError(code: "STREAM_ERROR", message: error.localizedDescription, details: nil))
        }
    }
}
