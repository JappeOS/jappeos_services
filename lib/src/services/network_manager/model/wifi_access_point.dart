import 'package:dbus/dbus.dart';

class WifiAccessPoint {
  final DBusObjectPath path;
  final String ssid;
  final int strength;
  final String security;
  final int frequency;
  final bool connected;

  WifiAccessPoint({
    required this.path,
    required this.ssid,
    required this.strength,
    required this.security,
    required this.frequency,
    required this.connected,
  });

  WifiAccessPoint copyWith({
    DBusObjectPath? path,
    String? ssid,
    int? strength,
    String? security,
    int? frequency,
    bool? connected,
  }) {
    return WifiAccessPoint(
      path: path ?? this.path,
      ssid: ssid ?? this.ssid,
      strength: strength ?? this.strength,
      security: security ?? this.security,
      frequency: frequency ?? this.frequency,
      connected: connected ?? this.connected,
    );
  }
}
