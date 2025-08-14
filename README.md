# FlutterScreenSharePlugin
[![Pub.dev](https://img.shields.io/pub/v/flutter_screen_share.svg)](https://pub.dev/packages/flutter_screen_share)

A Flutter plugin for macOS that enables screen sharing using Apple's ScreenCaptureKit (for macOS 12.3 and later) and CGDisplayStream (for earlier versions). This plugin supports real-time screen capture with WebP/JPEG encoding and integration with Flutter's texture system.

## Features
- Supports macOS screen sharing
- Uses **ScreenCaptureKit** for modern macOS versions (12.3+)
- Falls back to **CGDisplayStream** for older macOS versions
- Encodes frames as **WebP** or **JPEG**
- Supports **Flutter texture rendering**
- Provides **streaming frame data**
- Allows display and window selection for capture
- **NEW**: Audio capture from microphone and system audio

## Installation

Add the plugin to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_screen_share: ^latest_version
```

Run:
```sh
flutter pub get
```

## macOS Setup

### Info.plist Permissions
Add these permissions to your `macos/Runner/Info.plist` file:

```xml
<key>NSScreenCaptureUsageDescription</key>
<string>This app needs screen capture access.</string>
<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access for audio recording.</string>
<key>NSAppleEventsUsageDescription</key>
<string>This app needs permission to capture system audio</string>
```

### Entitlements
Modify your `macos/Runner/debug.entitlements` and `release.entitlements`:

```xml
<key>com.apple.security.screen-recording</key>
<true/>
<key>com.apple.security.device.screen-capture</key>
<true/> <!-- older mac versions -->
<key>com.apple.security.device.audio-input</key>
<true/>
<key>com.apple.security.device.microphone</key>
<true/>
```

## Usage

### 1. Import the Package

```dart
import 'package:flutter_screen_share/flutter_screen_share.dart';
```

### 2. Create a ScreenShareController

```dart
final controller = ScreenShareController();
```

### 3. Start Screen Capture

Using a Dialog:
```dart
controller.startCaptureWithDialog(
  context: context,
  onData: (Uint8List frame) {
    // Handle frame data
  },
);
```

Using a Specific Display:
```dart
final displays = await FlutterScreenShare.getDisplays();
if (displays.isNotEmpty) {
  final source = displays.first;
  controller.startCapture(
    source: source,
    onData: (Uint8List frame) {
      // Handle frame data
    },
  );
}
```

* **`onData`:** A callback function that receives the captured frame data as a `Uint8List`.
* **`source`:** A `Display` object representing either a display or a window. If null, the default display is used.

### 4. Display Captured Screen

```dart
ScreenShareView(controller: controller),
```

### 5. Stop Screen Capture

```dart
controller.stopCapture();
```

### 6. Stream Captured Frames

```dart
controller.frameStream?.listen((Uint8List frame) {
  // Process frame
});
```

## Audio Capture

### Start Audio Capture

```dart
try {
  String? filePath = await FlutterScreenShare.startAudioCapture();
  print('Recording started. File will be saved to: $filePath');
} catch (e) {
  print('Failed to start audio capture: $e');
}
```

### Stop Audio Capture

```dart
try {
  await FlutterScreenShare.stopAudioCapture();
  print('Recording stopped and file saved');
} catch (e) {
  print('Failed to stop audio capture: $e');
}
```

**Note**: Audio capture records both microphone input and system audio into an M4A file. Requires macOS 12.3+. See [AUDIO_CAPTURE.md](AUDIO_CAPTURE.md) for detailed documentation.

### 7. Encoding Options

```dart
final encodingOptions = EncodingOptions(type: "webp", fps: 30, quality: 0.9);
controller.startCapture(source: source, options: encodingOptions);
```

## Available Methods

| Method | Description |
|--------|-------------|
| `FlutterScreenShare.startCapture([Display? source, EncodingOptions? options])` | Starts screen capture |
| `FlutterScreenShare.getStream()` | Returns a stream of captured frames |
| `FlutterScreenShare.stopCapture()` | Stops screen capture |
| `FlutterScreenShare.getDisplays()` | Returns available displays |
| `FlutterScreenShare.getSources()` | Returns available sources (displays and windows) |
| `FlutterScreenShare.startAudioCapture()` | Starts audio capture from microphone and system audio |
| `FlutterScreenShare.stopAudioCapture()` | Stops audio capture |
| `ScreenShareController.startCaptureWithDialog(context, onData)` | Starts capture with a selection dialog |
| `ScreenShareController.startCapture(source, onData)` | Starts capture with a selected source |
| `ScreenShareController.stopCapture()` | Stops screen capture |
| `ScreenShareController.isSharing` | Indicates if sharing is active |
| `ScreenShareController.textureId` | Returns the texture ID |

## Notes
- Ensure permissions are granted.
- Works with **ScreenCaptureKit** (macOS 12.3+) and **CGDisplayStream** (earlier versions but it is marked deprecated by apple).
- Encodes frames in **WebP/JPEG**.
- The `ScreenShareController` manages screen sharing lifecycle.
- The `ScreenShareView` renders the captured screen using Flutter's texture API.

## License
[MIT License](LICENSE)

