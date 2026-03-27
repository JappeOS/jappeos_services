import 'package:dbus/dbus.dart';

import '../../../dbus_proxy.dart';

class BatteryDeviceProxy extends DbusProxy {
  static const interface =
      'org.jappeos.Core.PowerManagerService.BatteryDevice';

  static const kId = 'Id';
  static const kType = 'Type';
  static const kPowerSupply = 'PowerSupply';
  static const kIsPresent = 'IsPresent';
  static const kState = 'State';
  static const kChargePercentage = 'ChargePercentage';
  static const kTimeToEmpty = 'TimeToEmpty';
  static const kTimeToFull = 'TimeToFull';

  BatteryDeviceProxy(
    super.client,
    super.path,
  );

  Future<String> get id async =>
      (await object.getProperty(interface, kId)).asString();

  Future<String> get type async =>
      (await object.getProperty(interface, kType)).asString();

  Future<bool> get powerSupply async =>
      (await object.getProperty(interface, kPowerSupply)).asBoolean();

  Future<bool> get isPresent async =>
      (await object.getProperty(interface, kIsPresent)).asBoolean();

  Future<String> get state async =>
      (await object.getProperty(interface, kState)).asString();

  Future<double> get chargePercentage async =>
      (await object.getProperty(interface, kChargePercentage)).asDouble();

  Future<int> get timeToEmpty async =>
      (await object.getProperty(interface, kTimeToEmpty)).asInt64();

  Future<int> get timeToFull async =>
      (await object.getProperty(interface, kTimeToFull)).asInt64();
}
