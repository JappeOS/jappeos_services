import 'package:dbus/dbus.dart';

import 'dbus_proxy.dart';
import 'device_proxy.dart';

class WifiDeviceProxy extends DeviceProxy {
  static const interface =
      'org.jappeos.Core.NetworkManagerService.Device.WiFi';

  WifiDeviceProxy(
    super.client,
    super.path,
  );

  Future<void> scan() =>
      object.callMethod(interface, 'Scan', []);

  Future<void> connect({
    required String ssid,
    required String security,
    required String secret,
  }) =>
      object.callMethod(
        interface,
        'Connect',
        [
          DBusString(ssid),
          DBusString(security),
          DBusString(secret),
        ],
      );

  Future<void> disconnect() =>
      object.callMethod(interface, 'Disconnect', []);

  Future<List<DBusObjectPath>> get accessPoints async =>
      (await object.getProperty(interface, 'AccessPoints'))
          .asArray()
          .cast<DBusObjectPath>();

  /// Signal: AccessPointAdded(o)
  Stream<DBusObjectPath> accessPointAdded() =>
      DBusSignalStream(
        client,
        sender: serviceName,
        interface: interface,
        name: 'AccessPointAdded',
        path: object.path,
        signature: DBusSignature('o'),
      ).map((s) => s.values[0].asObjectPath());

  /// Signal: AccessPointRemoved(o)
  Stream<DBusObjectPath> accessPointRemoved() =>
      DBusSignalStream(
        client,
        sender: serviceName,
        interface: interface,
        name: 'AccessPointRemoved',
        path: object.path,
        signature: DBusSignature('o'),
      ).map((s) => s.values[0].asObjectPath());
}
