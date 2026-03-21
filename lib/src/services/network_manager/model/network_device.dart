import 'package:dbus/dbus.dart';

import '../../../utils.dart';
import 'network_connection.dart';
import 'wifi_access_point.dart';

enum NetworkDeviceType {
  wifi,
  ethernet,
  unknown,
}

enum NetworkDeviceState {
  unavailable,
  connected,
  connecting,
  disconnected,
  unknown,
}

class NetworkDevice {
  final DBusObjectPath path;
  final String id;
  final NetworkDeviceType type;
  final NetworkDeviceState state;
  final String hwAddress;
  final bool managed;
  final NetworkConnection? activeConnection;

  NetworkDevice({
    required this.path,
    required this.id,
    required this.type,
    required this.state,
    required this.hwAddress,
    required this.managed,
    this.activeConnection,
  });

  bool get isWifi => type == NetworkDeviceType.wifi;
  bool get isEthernet => type == NetworkDeviceType.ethernet;
  bool get isConnected => state == NetworkDeviceState.connected;
  bool get isUnavailable => state == NetworkDeviceState.unavailable;

  NetworkDevice copyWith({
    DBusObjectPath? path,
    String? id,
    NetworkDeviceType? type,
    NetworkDeviceState? state,
    String? hwAddress,
    bool? managed,
    Object? activeConnection = undefined,
  }) {
    return NetworkDevice(
      path: path ?? this.path,
      id: id ?? this.id,
      type: type ?? this.type,
      state: state ?? this.state,
      hwAddress: hwAddress ?? this.hwAddress,
      managed: managed ?? this.managed,
      activeConnection: activeConnection == undefined
          ? this.activeConnection
          : activeConnection as NetworkConnection?,
    );
  }
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
    super.activeConnection,
    required this.accessPoints,
  });

  @override
  NetworkWifiDevice copyWith({
    DBusObjectPath? path,
    String? id,
    NetworkDeviceType? type,
    NetworkDeviceState? state,
    String? hwAddress,
    bool? managed,
    Object? activeConnection = undefined,
    List<WifiAccessPoint>? accessPoints,
  }) {
    return NetworkWifiDevice(
      path: path ?? this.path,
      id: id ?? this.id,
      type: type ?? this.type,
      state: state ?? this.state,
      hwAddress: hwAddress ?? this.hwAddress,
      managed: managed ?? this.managed,
      activeConnection: activeConnection == undefined
          ? this.activeConnection
          : activeConnection as NetworkConnection?,
      accessPoints: accessPoints ?? this.accessPoints,
    );
  }
}
