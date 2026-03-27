import 'package:dbus/dbus.dart';

import 'services/service.dart';

abstract class DbusProxy {
  final DBusClient client;
  final DBusRemoteObject object;
  String get serviceName => object.name;

  DbusProxy(
    this.client,
    DBusObjectPath path,
  ) : object = DBusRemoteObject(
          client,
          name: Service.getName(client),
          path: path,
        );

  Stream<DBusPropertiesChangedSignal> propertiesChanged() {
    return DBusSignalStream(
      client,
      sender: serviceName,
      interface: 'org.freedesktop.DBus.Properties',
      name: 'PropertiesChanged',
      path: object.path,
      signature: DBusSignature('sa{sv}as'),
    ).map((signal) {
      return DBusPropertiesChangedSignal(signal);
    });
  }
}