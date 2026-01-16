import 'package:dbus/dbus.dart';

const serviceName = 'org.jappeos.Core.NetworkManagerService';

abstract class DbusProxy {
  final DBusClient client;
  final DBusRemoteObject object;

  DbusProxy(
    this.client,
    String service,
    DBusObjectPath path,
  ) : object = DBusRemoteObject(
          client,
          name: service,
          path: path,
        );
}
