import Foundation
import ScreenCaptureKit
import AVFoundation

@available(macOS 12.3, *)
class AudioCaptureManager: NSObject, SCStreamOutput {
    private var stream: SCStream?
    private var assetWriter: AVAssetWriter?
    private var micInput: AVAssetWriterInput?
    private var sysInput: AVAssetWriterInput?
    private var outputURL: URL?
    
    private let micQueue = DispatchQueue(label: "mic.queue")
    private let sysQueue = DispatchQueue(label: "sys.queue")
    
    func startAudioCapture(completion: @escaping (Result<String, Error>) -> Void) {
        // Setup output file path
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        outputURL = documentsPath.appendingPathComponent("audio_capture_\(Date().timeIntervalSince1970).m4a")
        
        guard let outputURL = outputURL else {
            completion(.failure(AudioCaptureError.fileSetupFailed))
            return
        }
        
        // Remove existing file if it exists
        try? FileManager.default.removeItem(at: outputURL)
        
        do {
            // Create asset writer
            assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .m4a)
            
            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVNumberOfChannelsKey: 2,
                AVSampleRateKey: 44100,
                AVEncoderBitRateKey: 128000
            ]
            
            // Create inputs
            micInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            sysInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            
            micInput?.expectsMediaDataInRealTime = true
            sysInput?.expectsMediaDataInRealTime = true
            
            // Add inputs to writer
            if let micInput = micInput {
                assetWriter?.add(micInput)
            }
            if let sysInput = sysInput {
                assetWriter?.add(sysInput)
            }
            
            // Start writing
            guard assetWriter?.startWriting() == true else {
                completion(.failure(AudioCaptureError.writerStartFailed))
                return
            }
            
            assetWriter?.startSession(atSourceTime: .zero)
            
            // Configure ScreenCaptureKit for audio capture
            let config = SCStreamConfiguration()
            config.captureMicrophone = true
            
            // Create empty filter (no screen content, just audio)
            let filter = SCContentFilter(desktopIndependentWindow: nil)
            
            stream = SCStream(filter: filter, configuration: config, delegate: nil)
            
            // Add stream outputs
            try stream?.addStreamOutput(self, type: .microphone, sampleHandlerQueue: micQueue)
            try stream?.addStreamOutput(self, type: .audio, sampleHandlerQueue: sysQueue)
            
            // Start capture
            stream?.startCapture { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(outputURL.path))
                }
            }
            
        } catch {
            completion(.failure(error))
        }
    }
    
    func stopAudioCapture(completion: @escaping (Result<Void, Error>) -> Void) {
        stream?.stopCapture { error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            // Finalize the asset writer
            self.assetWriter?.finishWriting {
                if self.assetWriter?.status == .completed {
                    completion(.success(()))
                } else {
                    completion(.failure(AudioCaptureError.finalizationFailed))
                }
            }
        }
    }
    
    // MARK: - SCStreamOutput
    
    public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard CMSampleBufferDataIsReady(sampleBuffer) else { return }
        
        switch type {
        case .microphone:
            if let micInput = micInput, micInput.isReadyForMoreMediaData {
                micInput.append(sampleBuffer)
            }
        case .audio:
            if let sysInput = sysInput, sysInput.isReadyForMoreMediaData {
                sysInput.append(sampleBuffer)
            }
        default:
            break
        }
    }
}

enum AudioCaptureError: Error {
    case fileSetupFailed
    case writerStartFailed
    case finalizationFailed
    
    var localizedDescription: String {
        switch self {
        case .fileSetupFailed:
            return "Failed to setup output file"
        case .writerStartFailed:
            return "Failed to start audio writer"
        case .finalizationFailed:
            return "Failed to finalize audio file"
        }
    }
}
