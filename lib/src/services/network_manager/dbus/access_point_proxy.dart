import 'package:dbus/dbus.dart';

import '../../../dbus_proxy.dart';

class AccessPointProxy extends DbusProxy {
  static const interface =
      'org.jappeos.Core.NetworkManagerService.AccessPoint';

  static const kSsid = 'Ssid';
  static const kStrength = 'Strength';
  static const kSecurity = 'Security';
  static const kFrequency = 'Frequency';
  static const kConnected = 'Connected';

  AccessPointProxy(
    super.client,
    super.path,
  );

  Future<String> get ssid async =>
      (await object.getProperty(interface, kSsid)).asString();

  Future<int> get strength async =>
      (await object.getProperty(interface, kStrength))
          .asInt32();

  Future<String> get security async =>
      (await object.getProperty(interface, kSecurity))
          .asString();

  Future<int> get frequency async =>
      (await object.getProperty(interface, kFrequency))
          .asInt32();

  Future<bool> get connected async =>
      (await object.getProperty(interface, kConnected))
          .asBoolean();
}
