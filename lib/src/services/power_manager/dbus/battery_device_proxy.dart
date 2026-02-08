import 'package:dbus/dbus.dart';

import '../../../dbus_proxy.dart';

class BatteryDeviceProxy extends DbusProxy {
  static const interface =
      'org.jappeos.Core.PowerManagerService.BatteryDevice';

  BatteryDeviceProxy(
    DBusClient client,
    DBusObjectPath path,
  ) : super(client, serviceName, path);

  Future<String> get id async =>
      (await object.getProperty(interface, 'Id')).asString();

  Future<String> get type async =>
      (await object.getProperty(interface, 'Type')).asString();

  Future<String> get state async =>
      (await object.getProperty(interface, 'State')).asString();

  Future<double> get chargePercentage async =>
      (await object.getProperty(interface, 'ChargePercentage')).asDouble();

  Future<int> get timeToEmpty async =>
      (await object.getProperty(interface, 'TimeToEmpty')).asInt64();

  Future<int> get timeToFull async =>
      (await object.getProperty(interface, 'TimeToFull')).asInt64();
}
