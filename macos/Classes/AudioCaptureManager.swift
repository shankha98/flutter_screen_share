import Foundation
import ScreenCaptureKit
import AVFoundation

@available(macOS 15.0, *)
class AudioCaptureManager: NSObject, SCStreamOutput {
    private var stream: SCStream?
    private var assetWriter: AVAssetWriter?
    private var audioInput: AVAssetWriterInput?
    private var outputURL: URL?
    private var enableLogging: Bool = false // Control audio logging
    
    private let audioQueue = DispatchQueue(label: "audio.queue")
    
    /// Starts audio capture including system audio and optionally microphone audio
    /// - Parameters:
    ///   - microphoneDeviceID: Optional microphone device ID. Use getAudioDevices() to get available devices. If nil, uses default microphone.
    ///   - enableLogging: Enable detailed console logging of audio data (default: false)
    ///   - completion: Completion handler with the output file path or error
    func startAudioCapture(microphoneDeviceID: String? = nil, enableLogging: Bool = false, completion: @escaping (Result<String, Error>) -> Void) {
        self.enableLogging = enableLogging
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
            // Log audio buffer information if enabled
            if enableLogging {
                logAudioSampleBuffer(sampleBuffer)
            }
            
            if let audioInput = audioInput, audioInput.isReadyForMoreMediaData {
                audioInput.append(sampleBuffer)
            }
        default:
            break
        }
    }
    
    // MARK: - Audio Logging
    
    private func logAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        // Get audio buffer information
        guard let audioBufferList = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            print("⚠️ AudioCapture: No data buffer in sample buffer")
            return
        }
        
        // Get format description
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else {
            print("⚠️ AudioCapture: No format description")
            return
        }
        
        let audioStreamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)
        
        // Log format information
        if let asbd = audioStreamBasicDescription?.pointee {
            print("🎵 AudioCapture Format:")
            print("   Sample Rate: \(asbd.mSampleRate) Hz")
            print("   Channels: \(asbd.mChannelsPerFrame)")
            print("   Bits Per Channel: \(asbd.mBitsPerChannel)")
            print("   Bytes Per Frame: \(asbd.mBytesPerFrame)")
            print("   Frames Per Packet: \(asbd.mFramesPerPacket)")
        }
        
        // Get sample count and duration
        let sampleCount = CMSampleBufferGetNumSamples(sampleBuffer)
        let duration = CMSampleBufferGetDuration(sampleBuffer)
        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        print("🎵 AudioCapture Buffer:")
        print("   Sample Count: \(sampleCount)")
        print("   Duration: \(CMTimeGetSeconds(duration)) seconds")
        print("   Presentation Time: \(CMTimeGetSeconds(presentationTime)) seconds")
        
        // Get actual audio data bytes
        var blockBuffer: CMBlockBuffer?
        var audioBufferListOut = AudioBufferList()
        var audioBufferListOutSize = MemoryLayout<AudioBufferList>.size
        
        let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: &audioBufferListOutSize,
            bufferListOut: &audioBufferListOut,
            bufferListSize: audioBufferListOutSize,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: 0,
            blockBufferOut: &blockBuffer
        )
        
        if status == noErr {
            let audioBuffer = audioBufferListOut.mBuffers
            let dataSize = audioBuffer.mDataByteSize
            
            print("🎵 AudioCapture Data:")
            print("   Data Size: \(dataSize) bytes")
            print("   Number of Channels: \(audioBufferListOut.mNumberBuffers)")
            
            // Log first few bytes of audio data for debugging
            if let audioData = audioBuffer.mData {
                let dataPointer = audioData.assumingMemoryBound(to: UInt8.self)
                let bytesToLog = min(Int(dataSize), 16) // Log first 16 bytes
                
                var hexString = ""
                var floatValues = ""
                
                for i in 0..<bytesToLog {
                    hexString += String(format: "%02X ", dataPointer[i])
                }
                
                // If it's float data, also show float values
                if let asbd = audioStreamBasicDescription?.pointee, asbd.mFormatFlags & kAudioFormatFlagIsFloat != 0 {
                    let floatPointer = audioData.assumingMemoryBound(to: Float32.self)
                    let floatsToLog = min(Int(dataSize) / 4, 4) // Log first 4 float values
                    
                    for i in 0..<floatsToLog {
                        floatValues += String(format: "%.6f ", floatPointer[i])
                    }
                    print("   First \(floatsToLog) float values: [\(floatValues)]")
                }
                
                print("   First \(bytesToLog) bytes (hex): \(hexString)")
            }
        } else {
            print("⚠️ AudioCapture: Failed to get audio buffer list, status: \(status)")
        }
        
        print("---")
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
