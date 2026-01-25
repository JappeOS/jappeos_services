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

  NetworkDeviceControllerBase(
    super.client,
    super.path,
  ) : deviceProxy = DeviceProxy(client, path);

  @override
  String get interfaceName => DeviceProxy.interface;

  // Lifecycle

  @override
  Future<T> loadInitial() async {
    final device = await loadDeviceSnapshot();

    final acPath = await deviceProxy.activeConnection;
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

  // Reducer

  @override
  T applyChanges(T current, Map<String, DBusValue> changed) {
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
    ) as T;
  }

  @override
  void onAfterUpdate(T old, T updated) {
    _handleActiveConnectionTransition(old, updated);
  }

  // Connection handling

  void _handleActiveConnectionTransition(
    T previous,
    T updated,
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
    assert(_connectionController == null);

    final controller = NetworkConnectionController(client, path);
    _connectionController = controller;

    controller.watch((connection) {
      emit(current!.copyWith(activeConnection: connection) as T);
    });

    controller.load().then((connection) {
      emit(current!.copyWith(activeConnection: connection) as T);
    });
  }

  // Extension point

  /// Subclasses must build the correct concrete device type
  Future<T> loadDeviceSnapshot();
}

class NetworkDeviceController
    extends NetworkDeviceControllerBase<NetworkDevice> {
  NetworkDeviceController(
    super.client,
    super.path,
  );

  @override
  Future<NetworkDevice> loadDeviceSnapshot() async {
    return NetworkDevice(
      path: path,
      id: await deviceProxy.id,
      type: NetworkDeviceType.values.byNameOrNull(
            await deviceProxy.type,
          ) ??
          NetworkDeviceType.unknown,
      state: NetworkDeviceState.values.byNameOrNull(
            await deviceProxy.state,
          ) ??
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

  final Map<DBusObjectPath, WifiAccessPointController>
      _apControllers = {};

  WifiDeviceController(
    super.client,
    super.path,
  )   : wifiProxy = WifiDeviceProxy(client, path);

  // Methods

  Future<void> scan() async {
    try {
      await wifiProxy.scan();
    } catch (e, st) {
      log.severe('WiFi scan failed', e, st);
    }
  }

  Future<void> connect({
    required String ssid,
    required String security,
    required String secret,
  }) async {
    try {
      await wifiProxy.connect(
        ssid: ssid,
        security: security,
        secret: secret,
      );
    } catch (e, st) {
      log.severe('WiFi connect failed', e, st);
    }
  }

  Future<void> disconnect() async {
    try {
      await wifiProxy.disconnect();
    } catch (e, st) {
      log.severe('WiFi disconnect failed', e, st);
    }
  }

  // Initial load

  @override
  Future<NetworkWifiDevice> loadDeviceSnapshot() async {
    final apPaths = await wifiProxy.accessPoints;

    for (final apPath in apPaths) {
      await _addAccessPoint(apPath);
    }

    return NetworkWifiDevice(
      path: path,
      id: await deviceProxy.id,
      type: NetworkDeviceType.wifi,
      state: NetworkDeviceState.values.byNameOrNull(
            await deviceProxy.state,
          ) ??
          NetworkDeviceState.unknown,
      hwAddress: await deviceProxy.hwAddress,
      managed: await deviceProxy.managed,
      activeConnection: null,
      accessPoints: [],
    );
  }

  // Watch APs

  @override
  Future<NetworkWifiDevice> loadInitial() async {
    final device = await super.loadInitial();

    wifiProxy.accessPointAdded().listen((path) {
      _addAccessPoint(path);
    });

    wifiProxy.accessPointRemoved().listen((path) {
      _removeAccessPoint(path);
    });

    return device;
  }

  // AP handling

  Future<void> _addAccessPoint(DBusObjectPath path) async {
    if (_apControllers.containsKey(path)) {
      _removeAccessPoint(path);
    }

    final controller = WifiAccessPointController(client, path);
    _apControllers[path] = controller;

    controller.watch((ap) {
      final updated = List<WifiAccessPoint>.from(
        current!.accessPoints,
      )..replaceWhere((a) => a.path == ap.path, (_) => ap);

      emit(current!.copyWith(accessPoints: updated));
    });

    final ap = await controller.load();

    emit(
      current!.copyWith(
        accessPoints: [...current!.accessPoints, ap],
      ),
    );
  }

  void _removeAccessPoint(DBusObjectPath path) {
    _apControllers.remove(path)?.dispose();

    emit(
      current!.copyWith(
        accessPoints: current!.accessPoints
            .where((a) => a.path != path)
            .toList(),
      ),
    );
  }
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