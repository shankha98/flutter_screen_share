import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_screen_share/flutter_screen_share.dart';

void main() {
  runApp(const MaterialApp(home: ScreenCapture()));
}

class ScreenCapture extends StatefulWidget {
  const ScreenCapture({super.key});

  @override
  State<ScreenCapture> createState() => _ScreenCaptureState();
}

class _ScreenCaptureState extends State<ScreenCapture> {
  ScreenShareController screenSharer = ScreenShareController();
  String? _audioFilePath;
  bool _isRecordingAudio = false;
  List<AudioDevice> _audioDevices = [];
  AudioDevice? _selectedAudioDevice;

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
        if (devices.isNotEmpty) {
          _selectedAudioDevice = devices.first; // Default to first device
        }
      });
    } catch (e) {
      debugPrint('Failed to load audio devices: $e');
    }
  }

  void startCapture() async {
    await screenSharer.startCaptureWithDialog(
      context: context,
      onData: (Uint8List frame) {
        debugPrint('Frame received: ${frame.length} bytes');
      },
    );
    setState(() {});
  }

  void stopCapture() async {
    await screenSharer.stopCapture();

    setState(() {});
  }

  Future<void> _startAudioCapture() async {
    try {
      setState(() {
        _isRecordingAudio = true;
      });

      final filePath = await FlutterScreenShare.startAudioCaptureWithDevice(
        _selectedAudioDevice,
      );

      setState(() {
        _audioFilePath = filePath;
      });

      debugPrint(
        'Audio capture started with device: ${_selectedAudioDevice?.name}. Recording to: $filePath',
      );
    } catch (e) {
      setState(() {
        _isRecordingAudio = false;
      });
      debugPrint('Failed to start audio capture: $e');
    }
  }

  Future<void> _stopAudioCapture() async {
    try {
      await FlutterScreenShare.stopAudioCapture();

      setState(() {
        _isRecordingAudio = false;
      });

      debugPrint('Audio capture stopped. File saved at: $_audioFilePath');
    } catch (e) {
      debugPrint('Failed to stop audio capture: $e');
    }
  }

  @override
  void dispose() {
    screenSharer.stopCapture();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Screen Share & Audio Capture')),
      body: ValueListenableBuilder(
        valueListenable: screenSharer.isSharing,
        builder: (context, isSharing, child) {
          return Column(
            children: [
              if (isSharing)
                Expanded(
                  child: Center(
                    child: ScreenShareView(controller: screenSharer),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Screen capture controls
                    ElevatedButton(
                      onPressed: !isSharing ? startCapture : stopCapture,
                      child: Text(
                        !isSharing
                            ? 'Start Screen Capture'
                            : 'Stop Screen Capture',
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Audio Capture',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Audio device selection
                    if (_audioDevices.isNotEmpty) ...[
                      Row(
                        children: [
                          const Text('Select Microphone:'),
                          const Spacer(),
                          IconButton(
                            onPressed:
                                _isRecordingAudio ? null : _loadAudioDevices,
                            icon: const Icon(Icons.refresh),
                            tooltip: 'Refresh Audio Devices',
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      DropdownButton<AudioDevice>(
                        value: _selectedAudioDevice,
                        isExpanded: true,
                        items:
                            _audioDevices.map((device) {
                              return DropdownMenuItem<AudioDevice>(
                                value: device,
                                child: Text(device.name),
                              );
                            }).toList(),
                        onChanged:
                            _isRecordingAudio
                                ? null
                                : (AudioDevice? device) {
                                  setState(() {
                                    _selectedAudioDevice = device;
                                  });
                                },
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (_audioFilePath != null)
                      Text(
                        'Recording to: ${_audioFilePath!.split('/').last}',
                        style: const TextStyle(fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _isRecordingAudio ? null : _startAudioCapture,
                      child: const Text('Start Audio Capture'),
                    ),
                    const SizedBox(height: 5),
                    ElevatedButton(
                      onPressed: !_isRecordingAudio ? null : _stopAudioCapture,
                      child: const Text('Stop Audio Capture'),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _isRecordingAudio
                          ? 'Recording Audio...'
                          : 'Audio Not Recording',
                      style: TextStyle(
                        color: _isRecordingAudio ? Colors.red : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
