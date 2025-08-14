# Audio Bytes Logging

The flutter_screen_share plugin now supports detailed console logging of audio data for debugging purposes.

## How to Enable Audio Logging

### From Flutter/Dart:

```dart
// Enable logging when starting audio capture
await FlutterScreenShare.startAudioCapture(null, true); // Device ID, Enable Logging

// Or with a specific device
await FlutterScreenShare.startAudioCaptureWithDevice(audioDevice, true);
```

### What Gets Logged:

When audio logging is enabled, you'll see detailed console output like this:

```
🎵 AudioCapture Format:
   Sample Rate: 44100.0 Hz
   Channels: 2
   Bits Per Channel: 32
   Bytes Per Frame: 8
   Frames Per Packet: 1

🎵 AudioCapture Buffer:
   Sample Count: 1024
   Duration: 0.023219954648526078 seconds
   Presentation Time: 12.345678 seconds

🎵 AudioCapture Data:
   Data Size: 8192 bytes
   Number of Channels: 1
   First 4 float values: [0.012345 -0.004567 0.009876 -0.001234 ]
   First 16 bytes (hex): 3C 48 A7 8D BC 95 D2 F1 3C 20 B0 72 BC 23 D7 0A
---
```

### Information Logged:

1. **Format Information:**
   - Sample Rate (Hz)
   - Number of channels
   - Bits per channel
   - Bytes per frame
   - Frames per packet

2. **Buffer Information:**
   - Number of audio samples in buffer
   - Duration of the audio buffer
   - Presentation timestamp

3. **Raw Audio Data:**
   - Total data size in bytes
   - First few audio samples as float values (if float format)
   - First 16 bytes in hexadecimal format

### Example Usage:

```dart
class AudioLoggingExample extends StatefulWidget {
  @override
  _AudioLoggingExampleState createState() => _AudioLoggingExampleState();
}

class _AudioLoggingExampleState extends State<AudioLoggingExample> {
  bool _enableLogging = false;
  bool _isRecording = false;
  
  Future<void> _startWithLogging() async {
    try {
      setState(() => _isRecording = true);
      
      // Start audio capture with logging enabled
      final filePath = await FlutterScreenShare.startAudioCapture(null, _enableLogging);
      
      print('Started recording with logging: $_enableLogging');
      print('File: $filePath');
    } catch (e) {
      setState(() => _isRecording = false);
      print('Error: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CheckboxListTile(
          title: Text('Enable Audio Logging'),
          subtitle: Text('Logs audio data to console for debugging'),
          value: _enableLogging,
          enabled: !_isRecording,
          onChanged: (value) => setState(() => _enableLogging = value ?? false),
        ),
        
        ElevatedButton(
          onPressed: _isRecording ? null : _startWithLogging,
          child: Text('Start Recording'),
        ),
      ],
    );
  }
}
```

### Use Cases for Audio Logging:

1. **Debugging Audio Issues:**
   - Check if audio data is being received
   - Verify audio format and sample rate
   - Monitor audio levels and data flow

2. **Performance Monitoring:**
   - Track buffer sizes and timing
   - Monitor audio latency
   - Check for dropped frames

3. **Audio Analysis:**
   - Inspect raw audio samples
   - Verify stereo/mono configuration
   - Debug audio format conversions

### Important Notes:

- ⚠️ **Performance Impact**: Logging adds computational overhead - only enable for debugging
- 🔧 **Console Output**: Logs appear in Xcode console or terminal when running the app
- 📊 **Data Volume**: Audio logging produces a lot of console output - use sparingly
- 🎯 **Development Only**: Disable logging in production builds

### Disabling Logging:

```dart
// Start without logging (default)
await FlutterScreenShare.startAudioCapture();

// Explicitly disable logging
await FlutterScreenShare.startAudioCapture(null, false);
```

The logging feature is designed to help developers understand and debug audio capture behavior during development.
