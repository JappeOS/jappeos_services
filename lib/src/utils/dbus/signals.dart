import 'package:dbus/dbus.dart';

Stream<DBusSignal> dbusSignals(
  DBusRemoteObject object,
  String interface,
  String name,
  DBusSignature signature,
) => DBusRemoteObjectSignalStream(
  object: object,
  interface: interface,
  name: name,
  signature: signature,
);

Stream<DBusPropertiesChangedSignal> dbusPropertiesChanged(
  DBusRemoteObject object, {
  String? interface,
}) => object.propertiesChanged.where(
  (signal) => interface == null || signal.propertiesInterface == interface,
);

/// Round trip on the same connection after installing signal listeners.
/// This orders the dbus package's queued AddMatch calls before snapshot reads.
Future<void> dbusSignalBarrier(DBusClient client) async {
  await client.callMethod(
    destination: 'org.freedesktop.DBus',
    path: DBusObjectPath('/org/freedesktop/DBus'),
    interface: 'org.freedesktop.DBus',
    name: 'GetId',
    replySignature: DBusSignature('s'),
  );
}
