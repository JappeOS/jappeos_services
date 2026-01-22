import 'package:dbus/dbus.dart';

import 'dbus_proxy.dart';

class NetworkManagerServiceProxy extends DbusProxy {
  NetworkManagerServiceProxy(DBusClient client)
      : super(
          client,
          serviceName,
          DBusObjectPath('/org/jappeos/Core/NetworkManagerService'),
          'org.jappeos.Core.NetworkManagerService',
        );

  Future<List<DBusObjectPath>> listDevices() async {
    final reply = await object.callMethod(
      interface,
      'ListDevices',
      [],
    );

    return (reply.returnValues.first as DBusArray)
        .children
        .cast<DBusObjectPath>();
  }

  /// Signal: DeviceAdded(o)
  Stream<DBusObjectPath> deviceAdded() =>
      DBusSignalStream(
        client,
        sender: serviceName,
        interface: interface,
        name: 'DeviceAdded',
        path: object.path,
        signature: DBusSignature('o'),
      ).map((signal) => signal.values[0].asObjectPath());

  /// Signal: DeviceRemoved(o)
  Stream<DBusObjectPath> deviceRemoved() =>
      DBusSignalStream(
        client,
        sender: serviceName,
        interface: interface,
        name: 'DeviceRemoved',
        path: object.path,
        signature: DBusSignature('o'),
      ).map((signal) => signal.values[0].asObjectPath());
}
