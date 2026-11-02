import 'package:dbus/dbus.dart';

import 'services/service.dart';
import 'utils/dbus/signals.dart';

abstract class DbusProxy {
  final DBusClient client;
  final DBusRemoteObject object;
  String get serviceName => object.name;

  DbusProxy(this.client, DBusObjectPath path, {String? serviceName})
    : object = DBusRemoteObject(
        client,
        name: serviceName ?? Service.getName(client),
        path: path,
      );

  Stream<DBusPropertiesChangedSignal> propertiesChanged({String? interface}) =>
      dbusPropertiesChanged(object, interface: interface);

  Stream<DBusSignal> signals(
    String interface,
    String name,
    DBusSignature signature,
  ) => dbusSignals(object, interface, name, signature);

  Stream<DBusObjectPath> objectPathSignals(String interface, String name) =>
      signals(
        interface,
        name,
        DBusSignature('o'),
      ).map((signal) => signal.values[0].asObjectPath());
}
