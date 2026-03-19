import 'package:dbus/dbus.dart';
import 'package:logging/logging.dart';

import '../../../logger.dart';
import '../../service.dart';

import 'dart:async';

import '../dbus/device_proxy.dart';
import '../dbus/network_manager_service_proxy.dart';
import '../model/network_device.dart';
import '../model/wifi_access_point.dart';
import 'network_device_controller.dart';

class NetworkManagerService extends Service {
  final Logger log = createLogger('NetworkManagerService');
  bool _initialized = false;
  late final NetworkManagerServiceProxy _proxy;

  final Map<DBusObjectPath, NetworkDeviceControllerBase>
      _controllers = {};

  final Map<DBusObjectPath, NetworkDevice> _devices = {};

  final List<StreamSubscription> _subs = [];

  NetworkManagerService() {
    _proxy = NetworkManagerServiceProxy(client);
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

  // Init

  Future<void> init() async {
    if (_initialized || !mounted) return;
    _initialized = true;

    try {
      await _loadInitialDevices();
      _subscribeSignals();
    } catch (e, st) {
      log.severe('NetworkManagerService init failed', e, st);
    }
  }

  // Cleanup

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  // Service methods

  Future<void> setEnabled(NetworkDevice device, bool enabled) async {
    final controller = _controllers[device.path];
    await controller!.setEnabled(enabled);
  }

  Future<void> scanWifi(NetworkDevice device) async {
    final controller = _controllers[device.path];
    if (controller is WifiDeviceController) {
      await controller.scan();
      return;
    }
    throw ArgumentError('Device is not a WiFi device');
  }

  Future<void> connectWifi(
    NetworkDevice device,
    WifiAccessPoint ap,
    String secret,
  ) async {
    final controller = _controllers[device.path];
    if (controller is WifiDeviceController) {
      await controller.connect(
        ssid: ap.ssid,
        security: ap.security,
        secret: secret,
      );
      return;
    }
    throw ArgumentError('Device is not a WiFi device');
  }

  Future<void> disconnectWifi(NetworkDevice device) async {
    final controller = _controllers[device.path];
    if (controller is WifiDeviceController) {
      await controller.disconnect();
      return;
    }
    throw ArgumentError('Device is not a WiFi device');
  }

  // Initial device load

  Future<void> _loadInitialDevices() async {
    final paths = await _proxy.listDevices();

    for (final path in paths) {
      await _addDevice(path, notify: false);
    }

    notifyListeners();
  }

  // Signal subscriptions

  void _subscribeSignals() {
    _subs.add(
      _proxy.deviceAdded().listen((path) async {
        await _addDevice(path);
      }),
    );

    _subs.add(
      _proxy.deviceRemoved().listen((path) {
        _removeDevice(path);
      }),
    );
  }

  // Device lifecycle

  Future<void> _addDevice(
    DBusObjectPath path, {
    bool notify = true,
  }) async {
    if (_controllers.containsKey(path)) return;

    final controller = await _createController(path);
    _controllers[path] = controller;

    controller.watch((device) {
      _devices[path] = device;
      notifyListeners();
    });

    final device = await controller.load();
    _devices[path] = device;

    if (notify) notifyListeners();
  }

  void _removeDevice(DBusObjectPath path) {
    _controllers.remove(path)?.dispose();
    _devices.remove(path);
    notifyListeners();
  }

  // Controller factory

  Future<NetworkDeviceControllerBase> _createController(
    DBusObjectPath path,
  ) async {
    final proxy = DeviceProxy(client, path);
    final type = await proxy.type;

    switch (type) {
      case 'wifi':
        return WifiDeviceController(client, path);
      default:
        return NetworkDeviceController(client, path);
    }
  }
}
