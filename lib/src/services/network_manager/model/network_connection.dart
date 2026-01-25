import 'package:dbus/dbus.dart';

enum NetworkConnectionState {
  activated,
  activating,
  deactivating,
  unknown,
}

class NetworkConnection {
  final DBusObjectPath path;
  final String id;
  final String type;
  final NetworkConnectionState state;
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

  NetworkConnection copyWith({
    DBusObjectPath? path,
    String? id,
    String? type,
    NetworkConnectionState? state,
    String? ip4Address,
    String? ip6Address,
    int? signalStrength,
  }) {
    return NetworkConnection(
      path: path ?? this.path,
      id: id ?? this.id,
      type: type ?? this.type,
      state: state ?? this.state,
      ip4Address: ip4Address ?? this.ip4Address,
      ip6Address: ip6Address ?? this.ip6Address,
      signalStrength: signalStrength ?? this.signalStrength,
    );
  }
}
