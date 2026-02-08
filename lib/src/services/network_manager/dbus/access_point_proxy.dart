import 'package:dbus/dbus.dart';

import '../../../dbus_proxy.dart';

class AccessPointProxy extends DbusProxy {
  static const interface =
      'org.jappeos.Core.NetworkManagerService.AccessPoint';

  AccessPointProxy(
    DBusClient client,
    DBusObjectPath path,
  ) : super(client, serviceName, path);

  Future<String> get ssid async =>
      (await object.getProperty(interface, 'Ssid')).asString();

  Future<int> get strength async =>
      (await object.getProperty(interface, 'Strength'))
          .asInt32();

  Future<String> get security async =>
      (await object.getProperty(interface, 'Security'))
          .asString();

  Future<int> get frequency async =>
      (await object.getProperty(interface, 'Frequency'))
          .asInt32();

  Future<bool> get connected async =>
      (await object.getProperty(interface, 'Connected'))
          .asBoolean();
}
