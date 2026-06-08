import 'package:dbus/dbus.dart';

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

  Future<int> connect({
    required String ssid,
    required String security,
    required String secret,
  }) async {
    final res = await object.callMethod(
      interface,
      'Connect',
      [
        DBusString(ssid),
        DBusString(security),
        DBusString(secret),
      ],
    );
    return res.values[0].asInt64();
  }

  Future<void> disconnect() =>
      object.callMethod(interface, 'Disconnect', []);

  Future<List<DBusObjectPath>> get accessPoints async =>
      (await object.getProperty(
        interface,
        'AccessPoints',
        signature: DBusSignature('ao')
      ))
          .asArray()
          .cast<DBusObjectPath>();

  /// Signal: ConnectResult(tbss)
  Stream<(
    int requestId,
    bool success,
    String reasonCode,
    String reasonMessage)> connectResult() =>
      DBusSignalStream(
        client,
        sender: serviceName,
        interface: interface,
        name: 'ConnectResult',
        path: object.path,
        signature: DBusSignature('tbss'),
      ).map((s) => (
        s.values[0].asInt64(),
        s.values[1].asBoolean(),
        s.values[2].asString(),
        s.values[3].asString()));

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
