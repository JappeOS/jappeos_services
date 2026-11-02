import 'package:dbus/dbus.dart';

import '../../../dbus_proxy.dart';

class NetworkManagerServiceProxy extends DbusProxy {
  static const interface = 'org.jappeos.Core.NetworkManagerService';

  NetworkManagerServiceProxy(
    DBusClient client, {
    String serviceName = 'org.jappeos.Core',
  }) : super(
         client,
         DBusObjectPath('/org/jappeos/Core/NetworkManagerService'),
         serviceName: serviceName,
       );

  Future<List<DBusObjectPath>> listDevices() async {
    final reply = await object.callMethod(interface, 'ListDevices', []);

    return (reply.returnValues.first as DBusArray).children
        .cast<DBusObjectPath>();
  }

  /// Signal: DeviceAdded(o)
  Stream<DBusObjectPath> deviceAdded() =>
      objectPathSignals(interface, 'DeviceAdded');

  /// Signal: DeviceRemoved(o)
  Stream<DBusObjectPath> deviceRemoved() =>
      objectPathSignals(interface, 'DeviceRemoved');
}
