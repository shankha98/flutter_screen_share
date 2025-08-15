import 'dart:typed_data';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_screen_share_method_channel.dart';
import 'src/display.dart';
import 'src/encoding.dart';

abstract class FlutterScreenSharePlatform extends PlatformInterface {
  /// Constructs a FlutterScreenSharePlatform.
  FlutterScreenSharePlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterScreenSharePlatform _instance =
      MethodChannelFlutterScreenShare();

  /// The default instance of [FlutterScreenSharePlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterScreenShare].
  static FlutterScreenSharePlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterScreenSharePlatform] when
  /// they register themselves.
  static set instance(FlutterScreenSharePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<Map> startCapture([Display? source, EncodingOptions? options]) {
    throw UnimplementedError('stopScreenCapture() has not been implemented.');
  }

  Stream<Uint8List> getStream() {
    throw UnimplementedError('stopScreenCapture() has not been implemented.');
  }

  Future<List<Display>> getDisplays() {
    throw UnimplementedError('stopScreenCapture() has not been implemented.');
  }

  Future<void> stopCapture() {
    throw UnimplementedError('stopScreenCapture() has not been implemented.');
  }

  Future<List<Display>> getSources() {
    throw UnimplementedError('stopScreenCapture() has not been implemented.');
  }

  Future<String?> startAudioCapture([
    String? microphoneDeviceID,
    bool captureMicrophone = true,
    bool enableLogging = false,
  ]) {
    throw UnimplementedError('startAudioCapture() has not been implemented.');
  }

  Future<void> stopAudioCapture() {
    throw UnimplementedError('stopAudioCapture() has not been implemented.');
  }

  Future<List<Map<String, dynamic>>> getAudioDevices() {
    throw UnimplementedError('getAudioDevices() has not been implemented.');
  }
}
