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

    if (changed.containsKey(AccessPointProxy.kSsid)) {
      ssid = changed[AccessPointProxy.kSsid]!.asString();
    }
    if (changed.containsKey(AccessPointProxy.kStrength)) {
      strength = changed[AccessPointProxy.kStrength]!.asInt32();
    }
    if (changed.containsKey(AccessPointProxy.kSecurity)) {
      security = changed[AccessPointProxy.kSecurity]!.asString();
    }
    if (changed.containsKey(AccessPointProxy.kFrequency)) {
      frequency = changed[AccessPointProxy.kFrequency]!.asInt32();
    }
    if (changed.containsKey(AccessPointProxy.kConnected)) {
      connected = changed[AccessPointProxy.kConnected]!.asBoolean();
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