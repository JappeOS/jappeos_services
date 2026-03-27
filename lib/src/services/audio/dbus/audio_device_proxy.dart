import 'package:dbus/dbus.dart';

import '../../../dbus_proxy.dart';

class AudioDeviceProxy extends DbusProxy {
  static const interface =
      'org.jappeos.Session.AudioService.Device';

  static const kId = 'Id';
  static const kName = 'Name';
  static const kType = 'Type';
  static const kDirection = 'Direction';
  static const kVolume = 'Volume';
  static const kMuted = 'Muted';
  static const kAvailable = 'Available';

  AudioDeviceProxy(
    super.client,
    super.path,
  );

  Future<void> setVolume(double volume) =>
      object.setProperty(interface, kVolume, DBusDouble(volume));

  Future<void> setMuted(bool muted) =>
      object.setProperty(interface, kMuted, DBusBoolean(muted));

  Future<String> get id async =>
      (await object.getProperty(interface, kId)).asString();

  Future<String> get name async =>
      (await object.getProperty(interface, kName)).asString();

  Future<String> get type async =>
      (await object.getProperty(interface, kType)).asString();

  Future<String> get direction async =>
      (await object.getProperty(interface, kDirection)).asString();

  Future<double> get volume async =>
      (await object.getProperty(interface, kVolume)).asDouble();

  Future<bool> get muted async =>
      (await object.getProperty(interface, kMuted)).asBoolean();

  Future<bool> get available async =>
      (await object.getProperty(interface, kAvailable)).asBoolean();
}
