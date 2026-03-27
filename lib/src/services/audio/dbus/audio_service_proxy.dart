import 'package:dbus/dbus.dart';

import '../../../dbus_proxy.dart';

class AudioServiceProxy extends DbusProxy {
  static const interface =
      'org.jappeos.Session.AudioService';

  static const kActiveInputDevice = 'ActiveInputDevice';
  static const kActiveOutputDevice = 'ActiveOutputDevice';

  AudioServiceProxy(DBusClient client)
      : super(
          client,
          serviceName,
          DBusObjectPath('/org/jappeos/Session/AudioService'),
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

  Future<List<DBusObjectPath>> listStreams() async {
    final reply = await object.callMethod(
      interface,
      'ListStreams',
      [],
    );

    return (reply.returnValues.first as DBusArray)
        .children
        .cast<DBusObjectPath>();
  }

  Future<void> setActiveInputDevice(DBusObjectPath device) =>
      object.setProperty(interface, kActiveInputDevice, device);

  Future<void> setActiveOutputDevice(DBusObjectPath device) =>
      object.setProperty(interface, kActiveOutputDevice, device);

  Future<DBusObjectPath> get activeInputDevice async =>
      (await object.getProperty(interface, kActiveInputDevice)).asObjectPath();

  Future<DBusObjectPath> get activeOutputDevice async =>
      (await object.getProperty(interface, kActiveOutputDevice)).asObjectPath();

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

  /// Signal: StreamAdded(o)
  Stream<DBusObjectPath> streamAdded() =>
      DBusSignalStream(
        client,
        sender: serviceName,
        interface: interface,
        name: 'StreamAdded',
        path: object.path,
        signature: DBusSignature('o'),
      ).map((signal) => signal.values[0].asObjectPath());

  /// Signal: StreamRemoved(o)
  Stream<DBusObjectPath> streamRemoved() =>
      DBusSignalStream(
        client,
        sender: serviceName,
        interface: interface,
        name: 'StreamRemoved',
        path: object.path,
        signature: DBusSignature('o'),
      ).map((signal) => signal.values[0].asObjectPath());
}
