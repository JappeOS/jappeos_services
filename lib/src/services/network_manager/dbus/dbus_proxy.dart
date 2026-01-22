import 'package:dbus/dbus.dart';

const serviceName = 'org.jappeos.Core';

abstract class DbusProxy {
  final DBusClient client;
  final DBusRemoteObject object;
  final String interface;

  DbusProxy(
    this.client,
    String service,
    DBusObjectPath path,
    this.interface,
  ) : object = DBusRemoteObject(
          client,
          name: service,
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
