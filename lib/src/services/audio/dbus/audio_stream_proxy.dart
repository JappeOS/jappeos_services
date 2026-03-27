import 'package:dbus/dbus.dart';

import '../../../dbus_proxy.dart';

class AudioStreamProxy extends DbusProxy {
  static const interface =
      'org.jappeos.Session.AudioService.Stream';

  static const kId = 'Id';
  static const kName = 'Name';
  static const kApplicationName = 'ApplicationName';
  static const kDirection = 'Direction';
  static const kDevice = 'Device';
  static const kVolume = 'Volume';
  static const kMuted = 'Muted';

  AudioStreamProxy(
    DBusClient client,
    DBusObjectPath path,
  ) : super(client, serviceName, path);

  Future<void> setDevice(DBusObjectPath device) =>
      object.setProperty(interface, kDevice, device);

  Future<void> setVolume(double volume) =>
      object.setProperty(interface, kVolume, DBusDouble(volume));

  Future<void> setMuted(bool muted) =>
      object.setProperty(interface, kMuted, DBusBoolean(muted));

  Future<String> get id async =>
      (await object.getProperty(interface, kId)).asString();

  Future<String> get name async =>
      (await object.getProperty(interface, kName)).asString();

  Future<String> get applicationName async =>
      (await object.getProperty(interface, kApplicationName)).asString();

  Future<String> get direction async =>
      (await object.getProperty(interface, kDirection)).asString();

  Future<DBusObjectPath> get device async =>
      (await object.getProperty(interface, kDevice)).asObjectPath();

  Future<double> get volume async =>
      (await object.getProperty(interface, kVolume)).asDouble();

  Future<bool> get muted async =>
      (await object.getProperty(interface, kMuted)).asBoolean();
}
