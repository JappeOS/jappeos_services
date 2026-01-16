import 'package:dbus/dbus.dart';

import 'wifi_access_point.dart';

enum NetworkDeviceType {
  wifi,
  ethernet,
  unknown,
}

enum NetworkDeviceState {
  connected,
  connecting,
  disconnected,
  unknown,
}

class NetworkDevice {
  final DBusObjectPath? path;
  final String id;
  final NetworkDeviceType type;
  final NetworkDeviceState state;
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

  bool get isWifi => type == NetworkDeviceType.wifi;
  bool get isEthernet => type == NetworkDeviceType.ethernet;
  bool get isConnected => state == NetworkDeviceState.connected;
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
