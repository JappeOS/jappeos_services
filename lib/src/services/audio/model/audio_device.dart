import 'package:dbus/dbus.dart';

import 'audio_direction.dart';

enum AudioDeviceType {
  input,
  output,
  unknown,
}

class AudioDevice {
  final DBusObjectPath path;
  final String id;
  final String name;
  final AudioDeviceType type;
  final AudioDirection direction;
  final double volume;
  final bool muted;
  final bool available;

  AudioDevice({
    required this.path,
    required this.id,
    required this.name,
    required this.type,
    required this.direction,
    required this.volume,
    required this.muted,
    required this.available,
  });

  AudioDevice copyWith({
    DBusObjectPath? path,
    String? id,
    String? name,
    AudioDeviceType? type,
    AudioDirection? direction,
    double? volume,
    bool? muted,
    bool? available,
  }) {
    return AudioDevice(
      path: path ?? this.path,
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      direction: direction ?? this.direction,
      volume: volume ?? this.volume,
      muted: muted ?? this.muted,
      available: available ?? this.available,
    );
  }
}