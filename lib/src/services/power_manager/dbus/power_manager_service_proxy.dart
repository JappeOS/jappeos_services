import 'package:dbus/dbus.dart';

import '../../../dbus_proxy.dart';

class PowerManagerServiceProxy extends DbusProxy {
  static const interface =
      'org.jappeos.Core.PowerManagerService';

  PowerManagerServiceProxy(DBusClient client)
      : super(
          client,
          DBusObjectPath('/org/jappeos/Core/PowerManagerService'),
        );

  Future<void> shutdown() =>
      object.callMethod(interface, 'Shutdown', []);

  Future<void> reboot() =>
      object.callMethod(interface, 'Reboot', []);

  Future<void> suspend() =>
      object.callMethod(interface, 'Suspend', []);

  Future<List<DBusObjectPath>> listBatteryDevices() async {
    final reply = await object.callMethod(
      interface,
      'ListBatteryDevices',
      [],
    );

    return (reply.returnValues.first as DBusArray)
        .children
        .cast<DBusObjectPath>();
  }

  /// Signal: DeviceAdded(o)
  Stream<DBusObjectPath> batteryDeviceAdded() =>
      DBusSignalStream(
        client,
        sender: serviceName,
        interface: interface,
        name: 'BatteryDeviceAdded',
        path: object.path,
        signature: DBusSignature('o'),
      ).map((signal) => signal.values[0].asObjectPath());

  /// Signal: DeviceRemoved(o)
  Stream<DBusObjectPath> batteryDeviceRemoved() =>
      DBusSignalStream(
        client,
        sender: serviceName,
        interface: interface,
        name: 'BatteryDeviceRemoved',
        path: object.path,
        signature: DBusSignature('o'),
      ).map((signal) => signal.values[0].asObjectPath());
}
