import 'package:dbus/dbus.dart';

import 'wifi_access_point.dart';

class NetworkDevice {
  final DBusObjectPath? path;
  final String id;
  final String type;
  final String state;
  final String hwAddress;
  final bool managed;
  final DBusObjectPath? activeConnectionPath;

  NetworkDevice({
    required this.path,
    required this.id,
    required this.type,
    required this.state,
    required this.hwAddress,
    required this.managed,
    this.activeConnectionPath,
  });

  bool get isWifi => type == 'wifi';
  bool get isConnected => state == 'activated';
}

class NetworkWifiDevice extends NetworkDevice {
  final List<WifiAccessPoint> accessPoints;

  NetworkWifiDevice({
    required super.path,
    required super.id,
    required super.type,
    required super.state,
    required super.hwAddress,
    required super.managed,
    super.activeConnectionPath,
    required this.accessPoints,
  });
}
