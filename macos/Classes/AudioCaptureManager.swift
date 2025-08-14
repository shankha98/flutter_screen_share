import Foundation
import ScreenCaptureKit
import AVFoundation

@available(macOS 15.0, *)
class AudioCaptureManager: NSObject, SCStreamOutput {
    private var stream: SCStream?
    private var assetWriter: AVAssetWriter?
    private var audioInput: AVAssetWriterInput?
    private var outputURL: URL?
    
    private let audioQueue = DispatchQueue(label: "audio.queue")
    
    /// Starts audio capture including system audio and optionally microphone audio
    /// - Parameters:
    ///   - microphoneDeviceID: Optional microphone device ID. Use getAudioDevices() to get available devices. If nil, uses default microphone.
    ///   - completion: Completion handler with the output file path or error
    func startAudioCapture(microphoneDeviceID: String? = nil, completion: @escaping (Result<String, Error>) -> Void) {
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
            
            // Create audio input
            audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            audioInput?.expectsMediaDataInRealTime = true
            
            // Add input to writer
            if let audioInput = audioInput {
                assetWriter?.add(audioInput)
            }
            
            // Start writing
            guard assetWriter?.startWriting() == true else {
                completion(.failure(AudioCaptureError.writerStartFailed))
                return
            }
            
            assetWriter?.startSession(atSourceTime: .zero)
            
            // Get available content for audio capture
            SCShareableContent.getWithCompletionHandler { content, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let content = content else {
                    completion(.failure(AudioCaptureError.noContentAvailable))
                    return
                }
                
                // Configure ScreenCaptureKit for audio capture
                let config = SCStreamConfiguration()
                config.capturesAudio = true
                config.excludesCurrentProcessAudio = true
                config.captureMicrophone = true
                
                // Configure audio settings
                config.sampleRate = 44100  // Match our audio settings
                config.channelCount = 2    // Match our audio settings (stereo)
                
                // Set microphone device if specified
                if let microphoneDeviceID = microphoneDeviceID {
                    config.microphoneCaptureDeviceID = microphoneDeviceID
                }

                // Create filter for system audio (no video content)
                let filter = SCContentFilter(display: content.displays.first!, excludingWindows: [])
                
                self.stream = SCStream(filter: filter, configuration: config, delegate: nil)
                
                // Add stream output for system audio
                do {
                    try self.stream?.addStreamOutput(self, type: .audio, sampleHandlerQueue: self.audioQueue)
                    
                    // Start capture
                    self.stream?.startCapture { error in
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
        case .audio:
            if let audioInput = audioInput, audioInput.isReadyForMoreMediaData {
                audioInput.append(sampleBuffer)
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
    case noContentAvailable
    
    var localizedDescription: String {
        switch self {
        case .fileSetupFailed:
            return "Failed to setup output file"
        case .writerStartFailed:
            return "Failed to start audio writer"
        case .finalizationFailed:
            return "Failed to finalize audio file"
        case .noContentAvailable:
            return "No shareable content available for audio capture"
        }
    }
}
