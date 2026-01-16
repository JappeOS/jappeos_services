import 'package:dbus/dbus.dart';

import '../../extensions.dart';
import '../service.dart';

import 'dart:async';

import 'dbus/access_point_proxy.dart';
import 'dbus/device_proxy.dart';
import 'dbus/network_manager_service_proxy.dart';
import 'dbus/wifi_device_proxy.dart';
import 'model/network_connection.dart';
import 'model/network_device.dart';
import 'model/wifi_access_point.dart';

class NetworkManagerService extends Service {
  bool _initialized = false;
  Future<void>? _initFuture;
  late final NetworkManagerServiceProxy _nm;

  final Map<DBusObjectPath, NetworkDevice> _devices = {};
  //final Map<DBusObjectPath, NetworkConnection> _connections = {};

  final List<StreamSubscription> _subscriptions = [];
  final Map<DBusObjectPath, List<StreamSubscription>>
    _deviceSubscriptions = {};

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
    return NetworkDevice(
      path: path,
      id: await proxy.id,
      type: NetworkDeviceType.values.byNameOrNull(await proxy.type)
              ?? NetworkDeviceType.unknown,
      state: NetworkDeviceState.values.byNameOrNull(await proxy.state)
              ?? NetworkDeviceState.unknown,
      hwAddress: await proxy.hwAddress,
      managed: await proxy.managed,
      activeConnectionPath: await proxy.activeConnection,
    );
  }

  Future<NetworkWifiDevice> _loadWifiDevice(
    DeviceProxy deviceProxy,
    DBusObjectPath path,
  ) async {
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
      activeConnectionPath: await deviceProxy.activeConnection,
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

        _devices.remove(path);
        _notifyOnce();
      }),
    );
  }

  void _watchDevice(DBusObjectPath path) {
    final deviceProxy = DeviceProxy(client, path);
    final subs = <StreamSubscription>[];

    subs.add(
      deviceProxy.stateChanged().listen((_) async {
        await _updateDevice(path);
        _notifyOnce();
      }),
    );

    _deviceSubscriptions[path] = subs;
  }

  void _watchWifiAccessPoints(
    DBusObjectPath devicePath,
    WifiDeviceProxy wifiProxy,
  ) {
    _subscriptions.add(
      wifiProxy.accessPointAdded().listen((_) async {
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

  void _notifyOnce() {
    if (_pendingNotify) return;
    _pendingNotify = true;

    scheduleMicrotask(() {
      _pendingNotify = false;
      notifyListeners();
    });
  }
}
