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
}

class DeviceStateChange {
  final String oldState;
  final String newState;

  DeviceStateChange({
    required this.oldState,
    required this.newState,
  });
}
