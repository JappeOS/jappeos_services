import 'package:dbus/dbus.dart';

class NetworkConnection {
  final DBusObjectPath path;
  final String id;
  final String type;
  final String state;
  final String ip4Address;
  final String ip6Address;
  final int signalStrength;

  NetworkConnection({
    required this.path,
    required this.id,
    required this.type,
    required this.state,
    required this.ip4Address,
    required this.ip6Address,
    required this.signalStrength,
  });
}
