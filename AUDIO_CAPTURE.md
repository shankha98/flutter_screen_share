# Audio Capture Feature

This document explains how to use the audio capture functionality in the Flutter Screen Share plugin.

## Overview

The audio capture feature uses macOS ScreenCaptureKit to record both microphone input and system audio into a single M4A file. This is useful for creating screen recordings with accompanying audio commentary and system sounds.

## Requirements

- macOS 12.3 or later
- Proper entitlements and permissions configured

## Setup

### 1. Entitlements

Add the following entitlements to your `DebugProfile.entitlements` and `Release.entitlements`:

```xml
<key>com.apple.security.device.audio-input</key>
<true/>
<key>com.apple.security.device.microphone</key>
<true/>
<key>com.apple.security.screen-recording</key>
<true/>
```

### 2. Info.plist Permissions

Add these permissions to your `Info.plist`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access to record your voice</string>
<key>NSScreenCaptureUsageDescription</key>
<string>This app needs access to screen recording to capture your screen</string>
<key>NSAppleEventsUsageDescription</key>
<string>This app needs permission to capture system audio</string>
```

## Usage

### Starting Audio Capture

```dart
try {
  String? filePath = await FlutterScreenShare.startAudioCapture();
  print('Recording started. File will be saved to: $filePath');
} catch (e) {
  print('Failed to start audio capture: $e');
}
```

### Stopping Audio Capture

```dart
try {
  await FlutterScreenShare.stopAudioCapture();
  print('Recording stopped and file saved');
} catch (e) {
  print('Failed to stop audio capture: $e');
}
```

## Technical Details

### Audio Format
- **Format**: M4A (MPEG-4 Audio)
- **Codec**: AAC
- **Sample Rate**: 44.1 kHz
- **Channels**: Stereo (2 channels)
- **Bit Rate**: 128 kbps

### File Location
Audio files are saved to the application's Documents directory with the naming pattern:
```
audio_capture_[timestamp].m4a
```

### What Gets Captured
- **Microphone Audio**: Voice input from the default microphone
- **System Audio**: All system sounds including:
  - Application audio
  - System notification sounds
  - Music and video playback
  - Any other audio output from the system

## Important Notes

1. **Screen Recording Permission**: Even though you're only capturing audio, macOS requires Screen Recording permission because system audio capture is considered part of screen recording functionality.

2. **Real-time Processing**: The audio capture uses real-time processing, so ensure your device has sufficient resources available.

3. **File Management**: The plugin creates new files for each recording session. You'll need to manage file cleanup in your application if needed.

4. **Concurrent Operations**: You can run audio capture alongside screen capture if needed.

## Error Handling

Common errors and their meanings:

- `UNSUPPORTED_VERSION`: macOS version is older than 12.3
- `AUDIO_CAPTURE_FAILED`: Failed to start audio capture (permissions, hardware issues)
- `AUDIO_STOP_FAILED`: Failed to properly stop and finalize the audio file

## Example Implementation

See the example app in `example/lib/main.dart` for a complete implementation showing both screen capture and audio capture functionality.
