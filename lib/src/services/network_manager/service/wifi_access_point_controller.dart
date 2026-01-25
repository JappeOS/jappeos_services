import 'package:dbus/dbus.dart';

import '../../../dbus_object_controller.dart';
import '../dbus/access_point_proxy.dart';
import '../model/wifi_access_point.dart';

class WifiAccessPointController
    extends DbusObjectController<WifiAccessPoint> {
  final AccessPointProxy _proxy;

  WifiAccessPointController(super.client, super.path)
      : _proxy = AccessPointProxy(client, path);

  @override
  String get interfaceName => AccessPointProxy.interface;

  @override
  Future<WifiAccessPoint> loadInitial() async {
    return WifiAccessPoint(
      path: path,
      ssid: await _proxy.ssid,
      strength: await _proxy.strength,
      security: await _proxy.security,
      frequency: await _proxy.frequency,
      connected: await _proxy.connected,
    );
  }

  @override
  WifiAccessPoint applyChanges(
    WifiAccessPoint current,
    Map<String, DBusValue> changed,
  ) {
    String? ssid;
    int? strength;
    String? security;
    int? frequency;
    bool? connected;

    if (changed.containsKey('Ssid')) {
      ssid = changed['Ssid']!.asString();
    }
    if (changed.containsKey('Strength')) {
      strength = changed['Strength']!.asInt32();
    }
    if (changed.containsKey('Security')) {
      security = changed['Security']!.asString();
    }
    if (changed.containsKey('Frequency')) {
      frequency = changed['Frequency']!.asInt32();
    }
    if (changed.containsKey('Connected')) {
      connected = changed['Connected']!.asBoolean();
    }

    if (ssid == null &&
        strength == null &&
        security == null &&
        frequency == null &&
        connected == null) {
      return current;
    }

    return current.copyWith(
      ssid: ssid,
      strength: strength,
      security: security,
      frequency: frequency,
      connected: connected,
    );
  }
}