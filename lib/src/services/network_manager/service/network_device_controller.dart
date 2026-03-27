import 'dart:async';

import 'package:dbus/dbus.dart';

import '../../../../jappeos_services.dart';
import '../../../dbus_object_controller.dart';
import '../../../extensions.dart';
import '../../../utils.dart';
import '../dbus/device_proxy.dart';
import '../dbus/wifi_device_proxy.dart';
import 'network_connection_controller.dart';
import 'wifi_access_point_controller.dart';

typedef DeviceUpdateCallback = void Function(NetworkDevice);

abstract class NetworkDeviceControllerBase<T extends NetworkDevice>
    extends DbusObjectController<T> {
  final DeviceProxy deviceProxy;

  NetworkConnectionController? _connectionController;
  DBusObjectPath _activeConnectionPath = DBusObjectPath.root;

  NetworkDeviceControllerBase(super.client, super.path)
    : deviceProxy = DeviceProxy(client, path);

  @override
  String get interfaceName => DeviceProxy.interface;

  // Lifecycle

  @override
  Future<T> loadInitial() async {
    return loadDeviceSnapshot();
  }

  @override
  Future<T> load() async {
    final device = await super.load();

    final acPath = await deviceProxy.activeConnection;
    _activeConnectionPath = acPath;
    if (acPath != DBusObjectPath.root && _connectionController == null) {
      _startConnectionController(acPath);
    }

    return device;
  }

  @override
  void dispose() {
    _connectionController?.dispose();
    _connectionController = null;
    super.dispose();
  }

  // Reducer

  @override
  T applyChanges(T current, Map<String, DBusValue> changed) {
    NetworkDeviceState? newState;
    Object? newActiveConnection = undefined;

    if (changed.containsKey(DeviceProxy.kState)) {
      newState =
          NetworkDeviceState.values.byNameOrNull(
            changed[DeviceProxy.kState]!.asString(),
          ) ??
          NetworkDeviceState.unknown;
    }

    if (changed.containsKey(DeviceProxy.kActiveConnection)) {
      final path = changed[DeviceProxy.kActiveConnection]!.asObjectPath();
      _activeConnectionPath = path;
      newActiveConnection =
          path == DBusObjectPath.root
              ? null
              : (current.activeConnection?.path == path
                  ? current.activeConnection
                  : null);
    }

    if (newState == null && newActiveConnection == undefined) {
      return current;
    }

    return current.copyWith(
          state: newState,
          activeConnection: newActiveConnection,
        )
        as T;
  }

  @override
  void onAfterUpdate(T old, T updated) {
    _handleActiveConnectionTransition(old, updated);
  }

  // Public methods

  /// Enables or disables the device. Throws on failure.
  Future<void> setEnabled(bool enabled) =>  deviceProxy.setEnabled(enabled);

  // Connection handling

  void _handleActiveConnectionTransition(T previous, T updated) {
    final prevPath = previous.activeConnection?.path ?? DBusObjectPath.root;
    final nextPath = _activeConnectionPath;

    if (prevPath == nextPath) return;

    _connectionController?.dispose();
    _connectionController = null;

    if (nextPath == DBusObjectPath.root) return;

    _startConnectionController(nextPath);
  }

  void _startConnectionController(DBusObjectPath path) {
    assert(_connectionController == null);

    final controller = NetworkConnectionController(client, path);
    _connectionController = controller;

    controller.watch((connection) {
      if (!identical(_connectionController, controller)) return;

      final device = current;
      if (device == null) return;

      emit(device.copyWith(activeConnection: connection) as T);
    });

    controller.load().then((connection) {
      if (!identical(_connectionController, controller)) return;

      final device = current;
      if (device == null) return;

      emit(device.copyWith(activeConnection: connection) as T);
    });
  }

  // Extension point

  /// Subclasses must build the correct concrete device type
  Future<T> loadDeviceSnapshot();
}

class NetworkDeviceController
    extends NetworkDeviceControllerBase<NetworkDevice> {
  NetworkDeviceController(super.client, super.path);

  @override
  Future<NetworkDevice> loadDeviceSnapshot() async {
    return NetworkDevice(
      path: path,
      id: await deviceProxy.id,
      type:
          NetworkDeviceType.values.byNameOrNull(await deviceProxy.type) ??
          NetworkDeviceType.unknown,
      state:
          NetworkDeviceState.values.byNameOrNull(await deviceProxy.state) ??
          NetworkDeviceState.unknown,
      hwAddress: await deviceProxy.hwAddress,
      managed: await deviceProxy.managed,
      activeConnection: null,
    );
  }
}

class WifiDeviceController
    extends NetworkDeviceControllerBase<NetworkWifiDevice> {
  final WifiDeviceProxy wifiProxy;

  final Map<DBusObjectPath, WifiAccessPointController> _apControllers = {};
  final List<StreamSubscription> _apSubs = [];

  WifiDeviceController(super.client, super.path)
    : wifiProxy = WifiDeviceProxy(client, path);

  // Public methods

  /// Scans Wi-Fi networks. Throws on failure.
  Future<void> scan() async {
    await wifiProxy.scan();
  }

  /// Connects to a Wi-Fi network. Throws on failure.
  /// It is recommended to handle [WifiAuthException] and
  /// [WifiConnectException] in UI.
  Future<void> connect({
    required String ssid,
    String security = "",
    String secret = "",
  }) async {
    try {
      final req = await wifiProxy.connect(
        ssid: ssid,
        security: security,
        secret: secret,
      );

      final res = await wifiProxy.connectResult()
          .firstWhere((item) => item.$1 == req)
          .timeout(const Duration(seconds: 25));

      if (res.$2) return;

      if (res.$3 == 'noSecrets' || res.$3 == 'loginFailed') {
        throw WifiAuthException();
      } else {
        throw WifiConnectException("Connect failed (${res.$3}): ${res.$4}");
      }
    } on DBusErrorException catch (e) {
      throw WifiConnectException(e.message);
    } on TimeoutException {
      throw WifiConnectException("Timed out while waiting for connection result");
    }
  }

  /// Disconnects from a Wi-Fi network. Throws on failure.
  Future<void> disconnect() async {
    await wifiProxy.disconnect();
  }

  // Initial load

  @override
  Future<NetworkWifiDevice> loadDeviceSnapshot() async {
    final apPaths = await wifiProxy.accessPoints;
    final seenPaths = <DBusObjectPath>{};
    final accessPoints = <WifiAccessPoint>[];

    for (final apPath in apPaths) {
      if (!seenPaths.add(apPath)) {
        continue;
      }

      final ap = await _addAccessPoint(apPath, emitUpdate: false);
      if (ap != null) {
        accessPoints.add(ap);
      }
    }

    return NetworkWifiDevice(
      path: path,
      id: await deviceProxy.id,
      type: NetworkDeviceType.wifi,
      state:
          NetworkDeviceState.values.byNameOrNull(await deviceProxy.state) ??
          NetworkDeviceState.unknown,
      hwAddress: await deviceProxy.hwAddress,
      managed: await deviceProxy.managed,
      activeConnection: null,
      accessPoints: accessPoints,
    );
  }

  // Watch APs

  @override
  Future<NetworkWifiDevice> load() async {
    final device = await super.load();

    _apSubs.add(
      wifiProxy.accessPointAdded().listen((path) {
        unawaited(_addAccessPoint(path));
      }),
    );

    _apSubs.add(
      wifiProxy.accessPointRemoved().listen((path) {
        _removeAccessPoint(path);
      }),
    );

    return device;
  }

  @override
  void dispose() {
    for (final sub in _apSubs) {
      sub.cancel();
    }
    _apSubs.clear();

    for (final controller in _apControllers.values) {
      controller.dispose();
    }
    _apControllers.clear();

    super.dispose();
  }

  // AP handling

  Future<WifiAccessPoint?> _addAccessPoint(
    DBusObjectPath path, {
    bool emitUpdate = true,
  }) async {
    if (_apControllers.containsKey(path)) {
      _removeAccessPoint(path, emitUpdate: false);
    }

    final controller = WifiAccessPointController(client, path);
    _apControllers[path] = controller;

    controller.watch((ap) {
      if (!identical(_apControllers[path], controller)) return;

      final device = current;
      if (device == null) return;

      final updated =
          device.accessPoints
              .map((existing) => existing.path == ap.path ? ap : existing)
              .toList();

      emit(device.copyWith(accessPoints: updated));
    });

    final ap = await controller.load();
    if (!identical(_apControllers[path], controller)) {
      return null;
    }

    if (!emitUpdate) {
      return ap;
    }

    final device = current;
    if (device == null) {
      return ap;
    }

    emit(
      device.copyWith(
        accessPoints: [
          ...device.accessPoints.where((existing) => existing.path != ap.path),
          ap,
        ],
      ),
    );

    return ap;
  }

  void _removeAccessPoint(DBusObjectPath path, {bool emitUpdate = true}) {
    _apControllers.remove(path)?.dispose();

    if (!emitUpdate) return;

    final device = current;
    if (device == null) return;

    emit(
      device.copyWith(
        accessPoints: device.accessPoints.where((a) => a.path != path).toList(),
      ),
    );
  }
}

class WifiAuthException implements Exception {}

class WifiConnectException implements Exception {
  final String message;

  WifiConnectException(this.message);
}

/*class NetworkDeviceController
    extends DbusObjectController<NetworkDevice> {
  final DeviceProxy _deviceProxy;

  NetworkConnectionController? _connectionController;

  NetworkDeviceController(super.client, super.path)
      : _deviceProxy = DeviceProxy(client, path);

  @override
  String get interfaceName => DeviceProxy.interface;

  @override
  Future<NetworkDevice> loadInitial() async {
    final device = await _loadFullDevice();
    final acPath = await _deviceProxy.activeConnection;
    if (acPath != DBusObjectPath.root) {
      _startConnectionController(acPath);
    }
    return device;
  }

  @override
  void dispose() {
    _connectionController?.dispose();
    _connectionController = null;
    super.dispose();
  }

  @override
  NetworkDevice applyChanges(
    NetworkDevice current,
    Map<String, DBusValue> changed,
  ) {
    NetworkDeviceState? newState;
    Object? newActiveConnection = undefined;

    if (changed.containsKey('State')) {
      newState = NetworkDeviceState.values.byNameOrNull(
            changed['State']!.asString(),
          ) ??
          NetworkDeviceState.unknown;
    }

    if (changed.containsKey('ActiveConnection')) {
      final path = changed['ActiveConnection']!.asObjectPath();
      newActiveConnection = path == DBusObjectPath.root ? null : path;
    }

    if (newState == null && newActiveConnection == undefined) {
      return current;
    }

    return current.copyWith(
      state: newState,
      activeConnection: newActiveConnection,
    );
  }

  @override
  void onAfterUpdate(NetworkDevice old, NetworkDevice updated) {
    _handleActiveConnectionTransition(old, updated);
  }

  void _handleActiveConnectionTransition(
    NetworkDevice previous,
    NetworkDevice updated,
  ) {
    final prevConn = previous.activeConnection;
    final nextConn = updated.activeConnection;

    if (prevConn?.path == nextConn?.path) return;

    _connectionController?.dispose();
    _connectionController = null;

    if (nextConn == null) return;

    _startConnectionController(nextConn.path);
  }

  void _startConnectionController(DBusObjectPath path) {
    final controller = NetworkConnectionController(client, path);

    _connectionController = controller;

    controller.watch((connection) {
      emit(
        current!.copyWith(activeConnection: connection),
      );
    });

    controller.load().then((connection) {
      emit(
        current!.copyWith(activeConnection: connection),
      );
    });
  }

  Future<NetworkDevice> _loadFullDevice() async {
    final base = NetworkDevice(
      path: path,
      id: await _deviceProxy.id,
      type: NetworkDeviceType.values.byNameOrNull(
            await _deviceProxy.type,
          ) ??
          NetworkDeviceType.unknown,
      state: NetworkDeviceState.values.byNameOrNull(
            await _deviceProxy.state,
          ) ??
          NetworkDeviceState.unknown,
      hwAddress: await _deviceProxy.hwAddress,
      managed: await _deviceProxy.managed,
      activeConnection: null,
    );

    if (base is NetworkWifiDevice) {
      // handled by WifiDeviceController in the future
      return base;
    }

    return base;
  }
}
*/
