import 'package:dbus/dbus.dart';

import '../../../dbus_proxy.dart';
import 'upower_proxy.dart';

class BatteryDeviceProxy extends DbusProxy {
  static const interface = 'org.freedesktop.UPower.Device';
  static const kId = 'Serial';
  static const kType = 'Type';
  static const kPowerSupply = 'PowerSupply';
  static const kIsPresent = 'IsPresent';
  static const kState = 'State';
  static const kChargePercentage = 'Percentage';
  static const kTimeToEmpty = 'TimeToEmpty';
  static const kTimeToFull = 'TimeToFull';

  BatteryDeviceProxy(
    super.client,
    super.path, {
    super.serviceName = UPowerProxy.destination,
  });

  Future<Map<String, DBusValue>> getProperties() =>
      object.getAllProperties(interface);
}
