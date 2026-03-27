import 'package:dbus/dbus.dart';

import '../../../dbus_object_controller.dart';
import '../../../extensions.dart';
import '../dbus/audio_stream_proxy.dart';
import '../model/audio_direction.dart';
import '../model/audio_stream.dart';

class AudioStreamController
    extends DbusObjectController<AudioStream> {
  final AudioStreamProxy _proxy;

  AudioStreamController(super.client, super.path)
      : _proxy = AudioStreamProxy(client, path);

  @override
  String get interfaceName => AudioStreamProxy.interface;

  @override
  Future<AudioStream> loadInitial() async {
    return AudioStream(
      path: path,
      id: await _proxy.id,
      name: await _proxy.name,
      applicationName: await _proxy.applicationName,
      direction: AudioDirection.values.byNameOrNull(
            await _proxy.direction,
          ) ??
          AudioDirection.unknown,
      device: await _proxy.device,
      volume: await _proxy.volume,
      muted: await _proxy.muted,
    );
  }

  @override
  AudioStream applyChanges(
    AudioStream current,
    Map<String, DBusValue> changed,
  ) {
    String? name;
    String? applicationName;
    DBusObjectPath? device;
    double? volume;
    bool? muted;

    if (changed.containsKey(AudioStreamProxy.kName)) {
      name = changed[AudioStreamProxy.kName]!.asString();
    }
    if (changed.containsKey(AudioStreamProxy.kApplicationName)) {
      applicationName = changed[AudioStreamProxy.kApplicationName]!.asString();
    }
    if (changed.containsKey(AudioStreamProxy.kDevice)) {
      device = changed[AudioStreamProxy.kDevice]!.asObjectPath();
    }
    if (changed.containsKey(AudioStreamProxy.kVolume)) {
      volume = changed[AudioStreamProxy.kVolume]!.asDouble();
    }
    if (changed.containsKey(AudioStreamProxy.kMuted)) {
      muted = changed[AudioStreamProxy.kMuted]!.asBoolean();
    }

    if (name == null &&
        applicationName == null &&
        device == null &&
        volume == null &&
        muted == null) {
      return current;
    }

    return current.copyWith(
      name: name,
      applicationName: applicationName,
      device: device,
      volume: volume,
      muted: muted,
    );
  }

  Future<void> setDevice(DBusObjectPath device) => _proxy.setDevice(device);
  Future<void> setVolume(double volume) => _proxy.setVolume(volume);
  Future<void> setMuted(bool muted) => _proxy.setMuted(muted);
}