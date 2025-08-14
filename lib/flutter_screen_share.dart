import 'dart:typed_data';

import 'flutter_screen_share_platform_interface.dart';
import 'src/display.dart';
import 'src/encoding.dart';
import 'src/audio_device.dart';

export 'src/display.dart';
export 'src/encoding.dart';
export 'src/screen_share_controller.dart';
export 'src/screen_share_view.dart';
export 'src/audio_device.dart';

class FlutterScreenShare {
  /// Starts the screen capture process.
  ///
  /// [source] is the display to capture, and [options] is the encoding options for the captured stream.
  ///
  /// Returns a future that completes with a map containing the capture settings.
  static Future<Map> startCapture([Display? source, EncodingOptions? options]) {
    return FlutterScreenSharePlatform.instance.startCapture(source, options);
  }

  /// Gets the stream of captured screen data.
  static Stream<Uint8List> getStream() {
    return FlutterScreenSharePlatform.instance.getStream();
  }

  /// Stops the screen capture process.
  static Future<void> stopCapture() {
    return FlutterScreenSharePlatform.instance.stopCapture();
  }

  /// Retrieves a list of available displays.
  static Future<List<Display>> getDisplays() {
    return FlutterScreenSharePlatform.instance.getDisplays();
  }

  /// Retrieves a list of available sources (displays and windows).
  static Future<List<Display>> _getSources() {
    return FlutterScreenSharePlatform.instance.getSources();
  }

  /// Retrieves a list of all available sources (displays and windows).
  static Future<List<Display>> getAllSources() {
    return _getSources();
  }

  /// Retrieves a list of available sources (displays and windows).
  ///
  /// Filters out sources that are not shareable.
  static Future<List<Display>> getSources([List<String>? filter]) async {
    final sources = await _getSources();
    final excludeOwners = [
      'Window Server',
      'Dock',
      'Wallpaper',
      'Control Centre',
      'Unknown App',
      if (filter != null) ...filter,
    ];
    final excludeName = [
      'Unknown App',
      'Item-0',
      if (filter != null) ...filter,
    ];
    final filtered =
        sources
            .where(
              (source) =>
                  source.name != null &&
                  source.name!.isNotEmpty &&
                  !excludeOwners.contains(source.owner) &&
                  !excludeName.contains(source.name) &&
                  source.name != 'Unknown App',
            )
            .toList();
    return filtered;
  }

  /// Retrieves a list of available audio input devices (microphones).
  ///
  /// Returns a list of [AudioDevice] objects representing all available microphones.
  static Future<List<AudioDevice>> getAudioDevices() async {
    try {
      final devices =
          await FlutterScreenSharePlatform.instance.getAudioDevices();
      return devices.map((device) => AudioDevice.fromMap(device)).toList();
    } catch (e) {
      // Re-throw with more context for debugging
      throw Exception('Failed to get audio devices: $e');
    }
  }

  /// Starts audio capture from microphone and system audio.
  ///
  /// [microphoneDeviceID] is optional - specify a device ID from [getAudioDevices]
  /// to use a specific microphone. If null, uses the default microphone.
  /// [enableLogging] enables detailed console logging of audio data (default: false).
  ///
  /// Returns the file path where the audio is being recorded.
  static Future<String?> startAudioCapture([
    String? microphoneDeviceID,
    bool enableLogging = false,
  ]) {
    return FlutterScreenSharePlatform.instance.startAudioCapture(
      microphoneDeviceID,
      enableLogging,
    );
  }

  /// Convenience method to start audio capture with an [AudioDevice].
  ///
  /// [audioDevice] is the microphone device to use. If null, uses the default microphone.
  /// [enableLogging] enables detailed console logging of audio data (default: false).
  ///
  /// Returns the file path where the audio is being recorded.
  static Future<String?> startAudioCaptureWithDevice([
    AudioDevice? audioDevice,
    bool enableLogging = false,
  ]) {
    return startAudioCapture(audioDevice?.id, enableLogging);
  }

  /// Stops the audio capture process.
  static Future<void> stopAudioCapture() {
    return FlutterScreenSharePlatform.instance.stopAudioCapture();
  }
}
