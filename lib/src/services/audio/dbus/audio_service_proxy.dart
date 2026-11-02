import 'package:dbus/dbus.dart';

import '../../../dbus_proxy.dart';

class AudioServiceProxy extends DbusProxy {
  static const interface = 'org.jappeos.Session.AudioService';

  static const kActiveInputDevice = 'ActiveInputDevice';
  static const kActiveOutputDevice = 'ActiveOutputDevice';

  AudioServiceProxy(
    DBusClient client, {
    String serviceName = 'org.jappeos.Session',
  }) : super(
         client,
         DBusObjectPath('/org/jappeos/Session/AudioService'),
         serviceName: serviceName,
       );

  Future<List<DBusObjectPath>> listDevices() async {
    final reply = await object.callMethod(interface, 'ListDevices', []);

    return (reply.returnValues.first as DBusArray).children
        .cast<DBusObjectPath>();
  }

  Future<List<DBusObjectPath>> listStreams() async {
    final reply = await object.callMethod(interface, 'ListStreams', []);

    return (reply.returnValues.first as DBusArray).children
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
      objectPathSignals(interface, 'DeviceAdded');

  /// Signal: DeviceRemoved(o)
  Stream<DBusObjectPath> deviceRemoved() =>
      objectPathSignals(interface, 'DeviceRemoved');

  /// Signal: StreamAdded(o)
  Stream<DBusObjectPath> streamAdded() =>
      objectPathSignals(interface, 'StreamAdded');

  /// Signal: StreamRemoved(o)
  Stream<DBusObjectPath> streamRemoved() =>
      objectPathSignals(interface, 'StreamRemoved');
}
