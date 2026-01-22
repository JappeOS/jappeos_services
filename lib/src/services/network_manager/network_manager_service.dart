import 'package:dbus/dbus.dart';

import '../../extensions.dart';
import '../service.dart';

import 'dart:async';

import 'dbus/access_point_proxy.dart';
import 'dbus/connection_proxy.dart';
import 'dbus/device_proxy.dart';
import 'dbus/network_manager_service_proxy.dart';
import 'dbus/wifi_device_proxy.dart';
import 'model/network_connection.dart';
import 'model/network_device.dart';
import 'model/wifi_access_point.dart';

// TODO: Architecture review and possible refactor
class NetworkManagerService extends Service {
  bool _initialized = false;
  Future<void>? _initFuture;
  late final NetworkManagerServiceProxy _nm;

  final Map<DBusObjectPath, NetworkDevice> _devices = {};
  //final Map<DBusObjectPath, NetworkConnection> _connections = {};

  final List<StreamSubscription> _subscriptions = [];
  final Map<DBusObjectPath, List<StreamSubscription>>
    _deviceSubscriptions = {};
  final Map<DBusObjectPath, StreamSubscription>
    _connectionSubscriptions = {};

  bool _pendingNotify = false;

  NetworkManagerService() {
    _nm = NetworkManagerServiceProxy(client);
    scheduleMicrotask(() => init());
  }

  List<NetworkDevice> get devices =>
      _devices.values.toList(growable: false);

  List<NetworkWifiDevice> get wifiDevices =>
      _devices.values
          .whereType<NetworkWifiDevice>()
          .toList(growable: false);

  List<NetworkDevice> get ethernetDevices =>
      _devices.values
          .where((d) => d.isEthernet)
          .toList(growable: false);

  /*NetworkWifiDevice? get activeWifi =>
      wifiDevices.firstWhereOrNull((d) => d.isConnected);*/

  Future<void> init() async {
    if (_initialized || !mounted) return;
    _initFuture = _initInternal();
    await _initFuture;
  }

  Future<void> _initInternal() async {
    await _loadInitialState();
    if (!mounted) return;
    _subscribeSignals();
    _initialized = true;
    _initFuture = null;
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    for (final s in _connectionSubscriptions.values) {
      s.cancel();
    }
    super.dispose();
  }

  Future<void> scanWifi(NetworkWifiDevice device) async {
    if (!_initialized) await _initFuture;

    final path = device.path;
    if (path == null) return;

    final wifi = WifiDeviceProxy(client, path);
    await wifi.scan();
  }

  Future<void> connectWifi(
    NetworkWifiDevice device,
    WifiAccessPoint ap,
    String secret,
  ) async {
    if (!_initialized) await _initFuture;

    final path = device.path;
    if (path == null) return;

    final wifi = WifiDeviceProxy(client, path);
    await wifi.connect(
      ssid: ap.ssid,
      security: ap.security,
      secret: secret,
    );
  }

  Future<void> _loadInitialState() async {
    final devicePaths = await _nm.listDevices();
    if (!mounted) return;

    for (final path in devicePaths) {
      await _addDevice(path);
      if (!mounted) return;
    }

    notifyListeners();
  }

  Future<void> _addDevice(DBusObjectPath path) async {
    final deviceProxy = DeviceProxy(client, path);

    final type = await deviceProxy.type;

    if (type == 'wifi') {
      _devices[path] = await _loadWifiDevice(deviceProxy, path);
      _watchWifiAccessPoints(path, deviceProxy as WifiDeviceProxy);
    } else {
      _devices[path] = await _loadGenericDevice(deviceProxy, path);
    }

    _watchDevice(path);
  }

  Future<NetworkDevice> _loadGenericDevice(
    DeviceProxy proxy,
    DBusObjectPath path,
  ) async {
    final acPath = await proxy.activeConnection;
    final activeConnection = acPath.value == '/' ? null : await _loadNetworkConnection(
      acPath,
    );

    return NetworkDevice(
      path: path,
      id: await proxy.id,
      type: NetworkDeviceType.values.byNameOrNull(await proxy.type)
              ?? NetworkDeviceType.unknown,
      state: NetworkDeviceState.values.byNameOrNull(await proxy.state)
              ?? NetworkDeviceState.unknown,
      hwAddress: await proxy.hwAddress,
      managed: await proxy.managed,
      activeConnection: activeConnection,
    );
  }

  Future<NetworkWifiDevice> _loadWifiDevice(
    DeviceProxy deviceProxy,
    DBusObjectPath path,
  ) async {
    final acPath = await deviceProxy.activeConnection;
    final activeConnection = acPath.value == '/' ? null : await _loadNetworkConnection(
      acPath,
    );

    final wifiProxy = WifiDeviceProxy(client, path);

    final apPaths = await wifiProxy.accessPoints;
    final aps = <WifiAccessPoint>[];

    for (final apPath in apPaths) {
      aps.add(await _loadAccessPoint(apPath));
    }

    return NetworkWifiDevice(
      path: path,
      id: await deviceProxy.id,
      type: NetworkDeviceType.values.byNameOrNull(await deviceProxy.type)
              ?? NetworkDeviceType.unknown,
      state: NetworkDeviceState.values.byNameOrNull(await deviceProxy.state)
              ?? NetworkDeviceState.unknown,
      hwAddress: await deviceProxy.hwAddress,
      managed: await deviceProxy.managed,
      activeConnection: activeConnection,
      accessPoints: aps,
    );
  }

  Future<WifiAccessPoint> _loadAccessPoint(
    DBusObjectPath path,
  ) async {
    final ap = AccessPointProxy(client, path);

    return WifiAccessPoint(
      ssid: await ap.ssid,
      strength: await ap.strength,
      security: await ap.security,
      frequency: await ap.frequency,
      connected: await ap.connected,
    );
  }

  Future<NetworkConnection> _loadNetworkConnection(
    DBusObjectPath path,
  ) async {
    final conn = ConnectionProxy(client, path);

    return NetworkConnection(
      path: path,
      id: await conn.id,
      type: await conn.type,
      state: NetworkConnectionState.values.byNameOrNull(await conn.state)
              ?? NetworkConnectionState.unknown,
      ip4Address: await conn.ip4Address,
      ip6Address: await conn.ip6Address,
      signalStrength: await conn.signalStrength,
    );
  }

  void _subscribeSignals() {
    _subscriptions.add(
      _nm.deviceAdded().listen((path) async {
        await _addDevice(path);
        _notifyOnce();
      }),
    );

    _subscriptions.add(
      _nm.deviceRemoved().listen((path) {
        _deviceSubscriptions[path]?.forEach((s) => s.cancel());
        _deviceSubscriptions.remove(path);

        final device = _devices[path];
        if (device?.activeConnection != null) {
          _unwatchConnection(device!.activeConnection!.path);
        }

        _devices.remove(path);
        _notifyOnce();
      }),
    );
  }

  void _watchDevice(DBusObjectPath path) {
    final proxy = DeviceProxy(client, path);
    final subs = <StreamSubscription>[];

    subs.add(
      proxy.propertiesChanged().listen((signal) async {
        if (signal.interface != proxy.interface) return;

        await _applyDevicePropertyChanges(path, signal.changedProperties);
        _notifyOnce();
      }),
    );

    _deviceSubscriptions[path] = subs;
  }

  void _watchConnection(
    DBusObjectPath devicePath,
    DBusObjectPath connectionPath,
  ) {
    // Avoid double-watching
    if (_connectionSubscriptions.containsKey(connectionPath)) return;

    final proxy = ConnectionProxy(client, connectionPath);

    _connectionSubscriptions[connectionPath] =
        proxy.propertiesChanged().listen((changed) async {
          await _applyConnectionPropertyChanges(
            devicePath,
            connectionPath,
            changed.changedProperties,
          );
          _notifyOnce();
        });
  }

  void _unwatchConnection(DBusObjectPath? path) {
    if (path == null) return;
    _connectionSubscriptions.remove(path)?.cancel();
  }

  void _watchWifiAccessPoints(
    DBusObjectPath devicePath,
    WifiDeviceProxy wifiProxy,
  ) {
    _subscriptions.add(
      wifiProxy.accessPointAdded().listen((_) async { // TODO: DO NOT UPDATE ENTIRE DEVICE
        await _updateDevice(devicePath);
        _notifyOnce();
      }),
    );

    _subscriptions.add(
      wifiProxy.accessPointRemoved().listen((_) async {
        await _updateDevice(devicePath);
        _notifyOnce();
      }),
    );
  }

  Future<void> _applyDevicePropertyChanges(
    DBusObjectPath path,
    Map<String, DBusValue> changed,
  ) async {
    final existing = _devices[path];
    if (existing == null) return;

    NetworkDeviceState? newState;
    NetworkConnection? newConnection = existing.activeConnection;

    if (changed.containsKey('State')) {
      newState = NetworkDeviceState.values.byNameOrNull(
        changed['State']!.asString(),
      ) ?? NetworkDeviceState.unknown;
    }

    if (changed.containsKey('ActiveConnection')) {
      final oldPath = existing.activeConnection?.path;
      final newPath = changed['ActiveConnection']!.asObjectPath();

      _unwatchConnection(oldPath);

      if (newPath.value == '/') {
        // disconnected
        newConnection = null;
      } else {
        newConnection = await _loadNetworkConnection(newPath);
        _watchConnection(path, newPath);
      }

      // replace device with new activeConnection
    }

    if (existing is NetworkWifiDevice) {
      _devices[path] = NetworkWifiDevice(
        path: existing.path,
        id: existing.id,
        type: existing.type,
        state: newState ?? existing.state,
        hwAddress: existing.hwAddress,
        managed: existing.managed,
        activeConnection: newConnection,
        accessPoints: existing.accessPoints,
      );
    } else {
      _devices[path] = NetworkDevice(
        path: existing.path,
        id: existing.id,
        type: existing.type,
        state: newState ?? existing.state,
        hwAddress: existing.hwAddress,
        managed: existing.managed,
        activeConnection: newConnection,
      );
    }
  }

  Future<void> _updateDevice(DBusObjectPath path) async {
    final existing = _devices[path];
    if (existing == null) return;

    final deviceProxy = DeviceProxy(client, path);

    if (existing is NetworkWifiDevice) {
      _devices[path] =
          await _loadWifiDevice(deviceProxy, path);
    } else {
      _devices[path] =
          await _loadGenericDevice(deviceProxy, path);
    }
  }

  Future<void> _applyConnectionPropertyChanges(
    DBusObjectPath devicePath,
    DBusObjectPath connectionPath,
    Map<String, DBusValue> changed,
  ) async {
    final device = _devices[devicePath];
    if (device == null) return;
    if (device.activeConnection?.path != connectionPath) return;

    final existing = device.activeConnection;
    if (existing == null) return;

    String id = existing.id;
    String type = existing.type;
    NetworkConnectionState state = existing.state;
    String ip4 = existing.ip4Address;
    String ip6 = existing.ip6Address;
    int strength = existing.signalStrength;

    if (changed.containsKey('Id')) {
      id = changed['Id']!.asString();
    }
    if (changed.containsKey('Type')) {
      type = changed['Type']!.asString();
    }
    if (changed.containsKey('State')) {
      state = NetworkConnectionState.values.byNameOrNull(changed['State']!.asString())
              ?? NetworkConnectionState.unknown;
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

    final updated = NetworkConnection(
      path: existing.path,
      id: id,
      type: type,
      state: state,
      ip4Address: ip4,
      ip6Address: ip6,
      signalStrength: strength,
    );

    _replaceDeviceConnection(devicePath, updated);
  }

  void _replaceDeviceConnection(
    DBusObjectPath devicePath,
    NetworkConnection updated,
  ) {
    final device = _devices[devicePath];
    if (device == null) return;

    if (device is NetworkWifiDevice) {
      _devices[devicePath] = NetworkWifiDevice(
        path: device.path,
        id: device.id,
        type: device.type,
        state: device.state,
        hwAddress: device.hwAddress,
        managed: device.managed,
        activeConnection: updated,
        accessPoints: device.accessPoints,
      );
    } else {
      _devices[devicePath] = NetworkDevice(
        path: device.path,
        id: device.id,
        type: device.type,
        state: device.state,
        hwAddress: device.hwAddress,
        managed: device.managed,
        activeConnection: updated,
      );
    }
  }

  void _notifyOnce() {
    if (_pendingNotify) return;
    _pendingNotify = true;

    scheduleMicrotask(() {
      _pendingNotify = false;
      notifyListeners();
    });
  }
}
