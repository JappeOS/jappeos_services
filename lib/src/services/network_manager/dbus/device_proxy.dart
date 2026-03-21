import 'package:dbus/dbus.dart';

import '../../../dbus_proxy.dart';

class DeviceProxy extends DbusProxy {
  static const interface =
      'org.jappeos.Core.NetworkManagerService.Device';

  static const kId = 'Id';
  static const kType = 'Type';
  static const kState = 'State';
  static const kHwAddress = 'HwAddress';
  static const kManaged = 'Managed';
  static const kActiveConnection = 'ActiveConnection';

  DeviceProxy(
    DBusClient client,
    DBusObjectPath path,
  ) : super(client, serviceName, path);

  Future<void> setEnabled(bool enabled) async {
    await object.callMethod(
      interface,
      'SetEnabled',
      [DBusBoolean(enabled)],
    );
  }

  Future<String> get id async =>
      (await object.getProperty(interface, kId)).asString();

  Future<String> get type async =>
      (await object.getProperty(interface, kType)).asString();

  Future<String> get state async =>
      (await object.getProperty(interface, kState)).asString();

  Future<String> get hwAddress async =>
      (await object.getProperty(interface, kHwAddress)).asString();

  Future<bool> get managed async =>
      (await object.getProperty(interface, kManaged)).asBoolean();

  Future<DBusObjectPath> get activeConnection async =>
      (await object
          .getProperty(interface, kActiveConnection))
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
