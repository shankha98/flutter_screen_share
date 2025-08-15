# Microphone Capture Parameter Implementation

## Overview
Added a configurable `captureMicrophone` boolean parameter to control whether microphone audio is captured during screen recording.

## Changes Made

### 1. AudioCaptureManager.swift
- Updated `startAudioCapture` method to accept `captureMicrophone: Bool = true` parameter
- Modified `config.captureMicrophone` to use the parameter value instead of hardcoded `true`
- Updated microphone device configuration to only apply when `captureMicrophone` is enabled

### 2. FlutterScreenSharePlugin.swift
- Updated method channel handler to extract `captureMicrophone` parameter from arguments
- Modified `startAudioCapture` method signature to include the new parameter
- Passed the parameter through to AudioCaptureManager

### 3. Flutter Platform Interface (flutter_screen_share_platform_interface.dart)
- Updated `startAudioCapture` method signature to include `captureMicrophone` parameter
- Set default value to `true` to maintain backward compatibility

### 4. Method Channel Implementation (flutter_screen_share_method_channel.dart)
- Modified `startAudioCapture` to accept and pass the `captureMicrophone` parameter
- Always includes the parameter in the method channel arguments

### 5. Main Flutter API (flutter_screen_share.dart)
- Updated both `startAudioCapture` and `startAudioCaptureWithDevice` methods
- Added parameter documentation
- Maintained backward compatibility with default value of `true`

## API Usage

```dart
// Capture system audio only (no microphone)
await FlutterScreenShare.startAudioCapture(
  null,                    // microphoneDeviceID
  false,                   // captureMicrophone
  false,                   // enableLogging
);

// Capture system audio + microphone (default behavior)
await FlutterScreenShare.startAudioCapture(
  "microphone-device-id",  // microphoneDeviceID
  true,                    // captureMicrophone (default)
  false,                   // enableLogging
);

// Using convenience method with AudioDevice
await FlutterScreenShare.startAudioCaptureWithDevice(
  audioDevice,             // AudioDevice or null
  true,                    // captureMicrophone (default)
  false,                   // enableLogging
);
```

## Backward Compatibility
- Default value of `captureMicrophone` is `true`, maintaining existing behavior
- All existing code will continue to work without changes
- New parameter is optional in all method signatures

## Implementation Notes
- The parameter controls the `SCStreamConfiguration.captureMicrophone` property
- When `captureMicrophone` is `false`, microphone device ID is ignored
- System audio capture is always enabled regardless of this parameter
- The change affects macOS 15.0+ implementations using ScreenCaptureKit
