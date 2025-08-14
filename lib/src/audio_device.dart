/// Represents an audio input device (microphone).
class AudioDevice {
  /// The unique identifier for the device.
  final String id;

  /// The display name of the device.
  final String name;

  /// The internal device ID (platform specific).
  final int deviceID;

  const AudioDevice({
    required this.id,
    required this.name,
    required this.deviceID,
  });

  /// Creates an [AudioDevice] from a map representation.
  factory AudioDevice.fromMap(Map<String, dynamic> map) {
    try {
      return AudioDevice(
        id: map['id'] as String,
        name: map['name'] as String,
        deviceID: map['deviceID'] as int,
      );
    } catch (e) {
      throw FormatException(
        'Failed to create AudioDevice from map: $map. Error: $e',
      );
    }
  }

  /// Converts this [AudioDevice] to a map representation.
  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'deviceID': deviceID};
  }

  @override
  String toString() {
    return 'AudioDevice(id: $id, name: $name, deviceID: $deviceID)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AudioDevice && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
