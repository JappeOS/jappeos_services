import 'package:dbus/dbus.dart';

import '../../../dbus_proxy.dart';

class UPowerProxy extends DbusProxy {
  static const destination = 'org.freedesktop.UPower';
  static const interface = 'org.freedesktop.UPower';
  static final displayDevicePath = DBusObjectPath(
    '/org/freedesktop/UPower/devices/DisplayDevice',
  );

  UPowerProxy(DBusClient client)
    : super(
        client,
        DBusObjectPath('/org/freedesktop/UPower'),
        serviceName: destination,
      );

  /// Accepts an owner-pinned object supplied by the collection watcher.
  static Future<List<DBusObjectPath>> enumerateDevices(
    DBusRemoteObject object,
  ) async {
    final response = await object.callMethod(
      interface,
      'EnumerateDevices',
      [],
      replySignature: DBusSignature('ao'),
    );
    return response.returnValues.single.asObjectPathArray().toList();
  }
}
