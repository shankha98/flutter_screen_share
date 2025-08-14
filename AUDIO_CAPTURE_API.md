# Audio Capture API Documentation

The flutter_screen_share plugin now supports enhanced audio capture with microphone device selection.

## Features

- 🎤 **System Audio Capture**: Capture audio from applications and system sounds
- 🎙️ **Microphone Audio Capture**: Capture audio from microphones simultaneously
- 🔧 **Device Selection**: Choose specific microphone devices
- 📱 **Device Discovery**: Get list of available audio input devices
- 🎵 **High Quality**: 44.1kHz, Stereo, AAC encoding in M4A format

## Requirements

- **macOS 15.0+** (due to ScreenCaptureKit microphone capture requirements)
- Microphone permissions in your app's `Info.plist`

## Permission Setup

Add these entries to your `macos/Runner/Info.plist`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access to record audio during screen capture.</string>
<key>NSScreenCaptureUsageDescription</key>
<string>This app needs access to screen recording to capture your screen.</string>
<key>NSAppleEventsUsageDescription</key>
<string>This app needs permission to capture system audio</string>
```

## API Reference

### Get Available Audio Devices

```dart
List<AudioDevice> devices = await FlutterScreenShare.getAudioDevices();

for (AudioDevice device in devices) {
  print('Device: ${device.name} (ID: ${device.id})');
}
```

### Start Audio Capture with Default Microphone

```dart
String? filePath = await FlutterScreenShare.startAudioCapture();
print('Recording to: $filePath');
```

### Start Audio Capture with Specific Microphone

```dart
// Method 1: Using device ID
String deviceId = "specific-microphone-id";
String? filePath = await FlutterScreenShare.startAudioCapture(deviceId);

// Method 2: Using AudioDevice object
AudioDevice selectedDevice = devices.first;
String? filePath = await FlutterScreenShare.startAudioCaptureWithDevice(selectedDevice);
```

### Stop Audio Capture

```dart
await FlutterScreenShare.stopAudioCapture();
```

## AudioDevice Model

```dart
class AudioDevice {
  final String id;        // Unique device identifier
  final String name;      // Display name (e.g., "Built-in Microphone")
  final int deviceID;     // Internal macOS device ID
}
```

## Complete Example

```dart
class AudioCaptureExample extends StatefulWidget {
  @override
  _AudioCaptureExampleState createState() => _AudioCaptureExampleState();
}

class _AudioCaptureExampleState extends State<AudioCaptureExample> {
  List<AudioDevice> _audioDevices = [];
  AudioDevice? _selectedDevice;
  bool _isRecording = false;
  String? _recordingPath;

  @override
  void initState() {
    super.initState();
    _loadAudioDevices();
  }

  Future<void> _loadAudioDevices() async {
    try {
      final devices = await FlutterScreenShare.getAudioDevices();
      setState(() {
        _audioDevices = devices;
        _selectedDevice = devices.isNotEmpty ? devices.first : null;
      });
    } catch (e) {
      print('Error loading audio devices: $e');
    }
  }

  Future<void> _startRecording() async {
    try {
      setState(() => _isRecording = true);
      
      final filePath = await FlutterScreenShare.startAudioCaptureWithDevice(_selectedDevice);
      
      setState(() => _recordingPath = filePath);
      print('Started recording to: $filePath');
    } catch (e) {
      setState(() => _isRecording = false);
      print('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      await FlutterScreenShare.stopAudioCapture();
      setState(() => _isRecording = false);
      print('Recording saved to: $_recordingPath');
    } catch (e) {
      print('Error stopping recording: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Audio Capture')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Device Selection
            if (_audioDevices.isNotEmpty) ...[
              Text('Select Microphone:'),
              DropdownButton<AudioDevice>(
                value: _selectedDevice,
                items: _audioDevices.map((device) {
                  return DropdownMenuItem(
                    value: device,
                    child: Text(device.name),
                  );
                }).toList(),
                onChanged: _isRecording ? null : (device) {
                  setState(() => _selectedDevice = device);
                },
              ),
            ],
            
            SizedBox(height: 20),
            
            // Recording Controls
            ElevatedButton(
              onPressed: _isRecording ? null : _startRecording,
              child: Text('Start Recording'),
            ),
            
            ElevatedButton(
              onPressed: !_isRecording ? null : _stopRecording,
              child: Text('Stop Recording'),
            ),
            
            // Status
            Text(
              _isRecording ? 'Recording...' : 'Not Recording',
              style: TextStyle(
                color: _isRecording ? Colors.red : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            if (_recordingPath != null)
              Text('File: ${_recordingPath!.split('/').last}'),
          ],
        ),
      ),
    );
  }
}
```

## Audio Configuration Details

The plugin automatically configures:

- **Sample Rate**: 44,100 Hz (CD quality)
- **Channels**: 2 (Stereo)
- **Format**: AAC (Advanced Audio Coding)
- **Container**: M4A
- **Bit Rate**: 128 kbps
- **System Audio**: Captured from display/applications
- **Process Exclusion**: Your app's own audio is excluded to prevent feedback loops

## Error Handling

```dart
try {
  await FlutterScreenShare.startAudioCapture();
} catch (e) {
  if (e.toString().contains('AUDIO_CAPTURE_FAILED')) {
    // Handle audio capture failure
  } else if (e.toString().contains('UNSUPPORTED_VERSION')) {
    // Handle unsupported macOS version
  }
}
```

## Notes

- Audio files are saved to the system's Documents directory
- Each recording session creates a new file with timestamp
- Both system audio and microphone audio are mixed into a single output file
- The plugin automatically handles proper cleanup of resources
