import 'package:dbus/dbus.dart';

import 'dbus_proxy.dart';

class ConnectionProxy extends DbusProxy {
  static const interface =
      'org.jappeos.Core.NetworkManagerService.Connection';

  ConnectionProxy(
    DBusClient client,
    DBusObjectPath path,
  ) : super(client, serviceName, path);

  Future<String> get id async =>
      (await object.getProperty(interface, 'Id')).asString();

  Future<String> get type async =>
      (await object.getProperty(interface, 'Type')).asString();

  Future<String> get state async =>
      (await object.getProperty(interface, 'State')).asString();

  Future<String> get ip4Address async =>
      (await object
              .getProperty(interface, 'Ip4Address'))
          .asString();

  Future<String> get ip6Address async =>
      (await object
              .getProperty(interface, 'Ip6Address'))
          .asString();

  Future<int> get signalStrength async =>
      (await object
              .getProperty(interface, 'SignalStrength'))
          .asInt32();
}
