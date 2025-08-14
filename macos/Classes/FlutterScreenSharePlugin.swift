import FlutterMacOS
import ScreenCaptureKit
import CoreImage
import Metal
import SDWebImage
import SDWebImageWebPCoder
import AudioToolbox

@available(macOS 15.0, *)
public class FlutterScreenSharePlugin: NSObject, FlutterPlugin, SCStreamDelegate {
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
            let args = call.arguments as? [String: Any]
            let microphoneDeviceID = args?["microphoneDeviceID"] as? String
            startAudioCapture(microphoneDeviceID: microphoneDeviceID, result)
        case "stopAudioCapture":
            stopAudioCapture(result)
        case "getAudioDevices":
            getAudioDevices(result)
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
    
    private func startAudioCapture(microphoneDeviceID: String? = nil, _ result: @escaping FlutterResult) {
        audioCaptureManager = AudioCaptureManager()
        audioCaptureManager?.startAudioCapture(microphoneDeviceID: microphoneDeviceID) { captureResult in
            DispatchQueue.main.async {
                switch captureResult {
                case .success(let filePath):
                    result(filePath)
                case .failure(let error):
                    result(FlutterError(code: "AUDIO_CAPTURE_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
    }
    
    private func stopAudioCapture(_ result: @escaping FlutterResult) {
        audioCaptureManager?.stopAudioCapture { captureResult in
            DispatchQueue.main.async {
                switch captureResult {
                case .success:
                    result(nil)
                case .failure(let error):
                    result(FlutterError(code: "AUDIO_STOP_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
        audioCaptureManager = nil
    }
    
    private func getAudioDevices(_ result: @escaping FlutterResult) {
        var inputDevices: [[String: Any]] = []
        
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize
        )
        
        guard status == noErr else {
            result(FlutterError(code: "AUDIO_DEVICES_ERROR", message: "Failed to get audio devices", details: nil))
            return
        }
        
        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        let devices = UnsafeMutablePointer<AudioDeviceID>.allocate(capacity: deviceCount)
        defer { devices.deallocate() }
        
        let getDevicesStatus = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            devices
        )
        
        guard getDevicesStatus == noErr else {
            result(FlutterError(code: "AUDIO_DEVICES_ERROR", message: "Failed to get audio devices", details: nil))
            return
        }
        
        for i in 0..<deviceCount {
            let deviceID = devices[i]
            
            // Check if device has input streams (microphone)
            var inputStreamsAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreamConfiguration,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )
            
            var inputStreamDataSize: UInt32 = 0
            let inputStreamStatus = AudioObjectGetPropertyDataSize(
                deviceID,
                &inputStreamsAddress,
                0,
                nil,
                &inputStreamDataSize
            )
            
            guard inputStreamStatus == noErr && inputStreamDataSize > 0 else {
                continue // Skip devices without input streams
            }
            
            // Get device name
            var nameAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceNameCFString,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            
            var nameSize: UInt32 = UInt32(MemoryLayout<CFString>.size)
            var deviceName: CFString?
            
            let nameStatus = AudioObjectGetPropertyData(
                deviceID,
                &nameAddress,
                0,
                nil,
                &nameSize,
                &deviceName
            )
            
            let name = (nameStatus == noErr && deviceName != nil) ? 
                String(describing: deviceName!) : "Unknown Device"
            
            // Get device UID (unique identifier)
            var uidAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceUID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            
            var uidSize: UInt32 = UInt32(MemoryLayout<CFString>.size)
            var deviceUID: CFString?
            
            let uidStatus = AudioObjectGetPropertyData(
                deviceID,
                &uidAddress,
                0,
                nil,
                &uidSize,
                &deviceUID
            )
            
            let uid = (uidStatus == noErr && deviceUID != nil) ? 
                String(describing: deviceUID!) : String(deviceID)
            
            inputDevices.append([
                "id": uid,
                "name": name,
                "deviceID": deviceID
            ])
        }
        
        result(inputDevices)
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
    }
    
    private func getSources(_ result: @escaping FlutterResult) {
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
    
    // MARK: - SCStreamDelegate
    public func stream(_ stream: SCStream, didStopWithError error: Error) {
        DispatchQueue.main.async {
            self.streamOutput?(FlutterError(code: "STREAM_ERROR", message: error.localizedDescription, details: nil))
        }
    }
}
