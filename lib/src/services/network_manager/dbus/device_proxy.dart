import 'package:dbus/dbus.dart';

import 'dbus_proxy.dart';

class DeviceProxy extends DbusProxy {
  static const interface =
      'org.jappeos.Core.NetworkManagerService.Device';

  DeviceProxy(
    DBusClient client,
    DBusObjectPath path,
  ) : super(client, serviceName, path);

  Future<String> get id async =>
      (await object.getProperty(interface, 'Id')).asString();

  Future<String> get type async =>
      (await object.getProperty(interface, 'Type')).asString();

  Future<String> get state async =>
      (await object.getProperty(interface, 'State')).asString();

  Future<String> get hwAddress async =>
      (await object.getProperty(interface, 'HwAddress')).asString();

  Future<bool> get managed async =>
      (await object.getProperty(interface, 'Managed')).asBoolean();

  Future<DBusObjectPath> get activeConnection async =>
      (await object
          .getProperty(interface, 'ActiveConnection'))
          .asObjectPath();

  /// Signal: StateChanged(s, s)
  Stream<DeviceStateChange> stateChanged() =>
      DBusSignalStream(
        client,
        sender: serviceName,
        interface: interface,
        name: 'StateChanged',
        path: object.path,
        signature: DBusSignature('ss'),
      ).map(
        (signal) => DeviceStateChange(
          oldState: signal.values[0].asString(),
          newState: signal.values[1].asString(),
        ),
      );
}

class DeviceStateChange {
  final String oldState;
  final String newState;

  DeviceStateChange({
    required this.oldState,
    required this.newState,
  });
}
