import 'package:dbus/dbus.dart';

import 'audio_direction.dart';

class AudioStream {
  final String id;
  final String name;
  final String applicationName;
  final AudioDirection direction;
  final DBusObjectPath device;
  final double volume;
  final bool muted;

  AudioStream({
    required this.id,
    required this.name,
    required this.applicationName,
    required this.direction,
    required this.device,
    required this.volume,
    required this.muted,
  });

  AudioStream copyWith({
    String? id,
    String? name,
    String? applicationName,
    AudioDirection? direction,
    DBusObjectPath? device,
    double? volume,
    bool? muted,
  }) {
    return AudioStream(
      id: id ?? this.id,
      name: name ?? this.name,
      applicationName: applicationName ?? this.applicationName,
      direction: direction ?? this.direction,
      device: device ?? this.device,
      volume: volume ?? this.volume,
      muted: muted ?? this.muted,
    );
  }
}