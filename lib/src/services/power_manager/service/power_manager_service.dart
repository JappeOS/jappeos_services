import 'dart:async';

import 'package:dbus/dbus.dart';
import 'package:logging/logging.dart';

import '../../../logger.dart';
import '../../service.dart';
import '../dbus/power_manager_service_proxy.dart';
import '../model/battery_device.dart';
import 'battery_device_controller.dart';

class PowerManagerService extends Service {
  final Logger log = createLogger('PowerManagerService');
  bool _initialized = false;
  late final PowerManagerServiceProxy _proxy;

  final Map<DBusObjectPath, BatteryDeviceController> _controllers = {};
  final Map<DBusObjectPath, BatteryDevice> _devices = {};
  final List<StreamSubscription> _subs = [];

  PowerManagerService() {
    _proxy = PowerManagerServiceProxy(client);
    scheduleMicrotask(() => init());
  }

  List<BatteryDevice> get devices =>
      _devices.values.toList(growable: false);

  // Init

  Future<void> init() async {
    if (_initialized || !mounted) return;
    _initialized = true;

    try {
      await _loadInitialDevices();
      _subscribeSignals();
    } catch (e, st) {
      log.severe('PowerManagerService init failed', e, st);
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

  /// Tries to shut down the system. Throws on failure.
  Future<void> shutdown() async => await _proxy.shutdown();

  /// Tries to reboot the system. Throws on failure.
  Future<void> reboot() async => await _proxy.reboot();

  /// Tries to suspend the system. Throws on failure.
  Future<void> suspend() async => await _proxy.suspend();

  // Initial device load

  Future<void> _loadInitialDevices() async {
    final paths = await _proxy.listBatteryDevices();

    for (final path in paths) {
      await _addDevice(path, notify: false);
    }

    notifyListeners();
  }

  // Signal subscriptions

  void _subscribeSignals() {
    _subs.add(
      _proxy.batteryDeviceAdded().listen((path) async {
        await _addDevice(path);
      }),
    );

    _subs.add(
      _proxy.batteryDeviceRemoved().listen((path) {
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

    final controller = BatteryDeviceController(client, path);
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
}