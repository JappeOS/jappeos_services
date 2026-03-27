import 'package:dbus/dbus.dart';

import '../../../dbus_proxy.dart';

class ConnectionProxy extends DbusProxy {
  static const interface =
      'org.jappeos.Core.NetworkManagerService.Connection';

  static const kId = 'Id';
  static const kType = 'Type';
  static const kState = 'State';
  static const kIp4Address = 'Ip4Address';
  static const kIp6Address = 'Ip6Address';
  static const kSignalStrength = 'SignalStrength';

  ConnectionProxy(
    super.client,
    super.path,
  );

  Future<String> get id async =>
      (await object.getProperty(interface, kId)).asString();

  Future<String> get type async =>
      (await object.getProperty(interface, kType)).asString();

  Future<String> get state async =>
      (await object.getProperty(interface, kState)).asString();

  Future<String> get ip4Address async =>
      (await object
              .getProperty(interface, kIp4Address))
          .asString();

  Future<String> get ip6Address async =>
      (await object
              .getProperty(interface, kIp6Address))
          .asString();

  Future<int> get signalStrength async =>
      (await object
              .getProperty(interface, kSignalStrength))
          .asInt32();
}
