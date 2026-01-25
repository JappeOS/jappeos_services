import 'package:dbus/dbus.dart';

import '../../../../jappeos_services.dart';
import '../../../dbus_object_controller.dart';
import '../../../extensions.dart';
import '../dbus/connection_proxy.dart';

class NetworkConnectionController
    extends DbusObjectController<NetworkConnection> {
  final ConnectionProxy _proxy;

  NetworkConnectionController(super.client, super.path)
      : _proxy = ConnectionProxy(client, path);

  @override
  String get interfaceName => ConnectionProxy.interface;

  @override
  Future<NetworkConnection> loadInitial() async {
    return NetworkConnection(
      path: path,
      id: await _proxy.id,
      type: await _proxy.type,
      state: NetworkConnectionState.values.byNameOrNull(
            await _proxy.state,
          ) ??
          NetworkConnectionState.unknown,
      ip4Address: await _proxy.ip4Address,
      ip6Address: await _proxy.ip6Address,
      signalStrength: await _proxy.signalStrength,
    );
  }

  @override
  NetworkConnection applyChanges(
    NetworkConnection current,
    Map<String, DBusValue> changed,
  ) {
    NetworkConnectionState? state;
    String? ip4;
    String? ip6;
    int? strength;

    if (changed.containsKey('State')) {
      state = NetworkConnectionState.values.byNameOrNull(
            changed['State']!.asString(),
          ) ??
          NetworkConnectionState.unknown;
    }
    if (changed.containsKey('Ip4Address')) {
      ip4 = changed['Ip4Address']!.asString();
    }
    if (changed.containsKey('Ip6Address')) {
      ip6 = changed['Ip6Address']!.asString();
    }
    if (changed.containsKey('SignalStrength')) {
      strength = changed['SignalStrength']!.asInt32();
    }

    if (state == null &&
        ip4 == null &&
        ip6 == null &&
        strength == null) {
      return current;
    }

    return current.copyWith(
      state: state,
      ip4Address: ip4,
      ip6Address: ip6,
      signalStrength: strength,
    );
  }
}