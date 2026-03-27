import 'package:dbus/dbus.dart';

import '../../../dbus_object_controller.dart';
import '../../../extensions.dart';
import '../dbus/audio_device_proxy.dart';
import '../model/audio_device.dart';
import '../model/audio_direction.dart';

class AudioDeviceController
    extends DbusObjectController<AudioDevice> {
  final AudioDeviceProxy _proxy;

  AudioDeviceController(super.client, super.path)
      : _proxy = AudioDeviceProxy(client, path);

  @override
  String get interfaceName => AudioDeviceProxy.interface;

  @override
  Future<AudioDevice> loadInitial() async {
    return AudioDevice(
      path: path,
      id: await _proxy.id,
      name: await _proxy.name,
      type: AudioDeviceType.values.byNameOrNull(
            await _proxy.type,
          ) ??
          AudioDeviceType.unknown,
      direction: AudioDirection.values.byNameOrNull(
            await _proxy.direction,
          ) ??
          AudioDirection.unknown,
      volume: await _proxy.volume,
      muted: await _proxy.muted,
      available: await _proxy.available,
    );
  }

  @override
  AudioDevice applyChanges(
    AudioDevice current,
    Map<String, DBusValue> changed,
  ) {
    String? name;
    double? volume;
    bool? muted;
    bool? available;

    if (changed.containsKey(AudioDeviceProxy.kName)) {
      name = changed[AudioDeviceProxy.kName]!.asString();
    }
    if (changed.containsKey(AudioDeviceProxy.kVolume)) {
      volume = changed[AudioDeviceProxy.kVolume]!.asDouble();
    }
    if (changed.containsKey(AudioDeviceProxy.kMuted)) {
      muted = changed[AudioDeviceProxy.kMuted]!.asBoolean();
    }
    if (changed.containsKey(AudioDeviceProxy.kAvailable)) {
      available = changed[AudioDeviceProxy.kAvailable]!.asBoolean();
    }

    if (name == null &&
        volume == null &&
        muted == null &&
        available == null) {
      return current;
    }

    return current.copyWith(
      name: name,
      volume: volume,
      muted: muted,
      available: available,
    );
  }

  Future<void> setVolume(double volume) => _proxy.setVolume(volume);
  Future<void> setMuted(bool muted) => _proxy.setMuted(muted);
}