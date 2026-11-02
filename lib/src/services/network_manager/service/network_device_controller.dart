import 'dart:async';

import 'package:dbus/dbus.dart';

import '../../../../jappeos_services.dart';
import '../../../utils/dbus/object_controller.dart';
import '../../../extensions.dart';
import '../../../utils.dart';
import '../../../utils/dbus/object_collection.dart';
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

  NetworkDeviceControllerBase(
    super.client,
    super.path, {
    super.serviceName = 'org.jappeos.Core',
  }) : deviceProxy = DeviceProxy(client, path, serviceName: serviceName);

  @override
  String get interfaceName => DeviceProxy.interface;

  // Lifecycle

  @override
  Future<T> loadInitial() async {
    final device = await loadDeviceSnapshot();
    _activeConnectionPath = await deviceProxy.activeConnection;
    return device.copyWith(
          activeConnection:
              device.activeConnection?.path == _activeConnectionPath
                  ? device.activeConnection
                  : null,
        )
        as T;
  }

  @override
  Future<T> load() async {
    final device = await super.load();

    if (isDisposed) return device;
    _syncConnectionController();

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
  Future<void> setEnabled(bool enabled) => deviceProxy.setEnabled(enabled);

  // Connection handling

  void _handleActiveConnectionTransition(T previous, T updated) {
    _syncConnectionController();
  }

  void _syncConnectionController() {
    final nextPath = _activeConnectionPath;
    if (_connectionController?.path == nextPath) return;
    _connectionController?.dispose();
    _connectionController = null;
    if (nextPath != DBusObjectPath.root && !isDisposed) {
      _startConnectionController(nextPath);
    }
  }

  void _startConnectionController(DBusObjectPath path) {
    assert(_connectionController == null);

    final controller = NetworkConnectionController(
      client,
      path,
      serviceName: serviceName,
    );
    _connectionController = controller;

    controller.watch((connection) {
      if (!identical(_connectionController, controller)) return;

      final device = current;
      if (device == null) return;

      emit(device.copyWith(activeConnection: connection) as T);
    });

    unawaited(
      controller.load().then<void>(
        (_) {},
        onError: (Object error, StackTrace stack) {
          if (!isDisposed && identical(_connectionController, controller)) {
            log.warning('Connection load failed', error, stack);
            _connectionController = null;
            controller.dispose();
          }
        },
      ),
    );
  }

  // Extension point

  /// Subclasses must build the correct concrete device type
  Future<T> loadDeviceSnapshot();
}

class NetworkDeviceController
    extends NetworkDeviceControllerBase<NetworkDevice> {
  NetworkDeviceController(
    super.client,
    super.path, {
    super.serviceName = 'org.jappeos.Core',
  });

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
      activeConnection: current?.activeConnection,
    );
  }
}

class WifiDeviceController
    extends NetworkDeviceControllerBase<NetworkWifiDevice> {
  final WifiDeviceProxy wifiProxy;

  late final DbusObjectCollection<WifiAccessPoint, WifiAccessPointController>
  _accessPoints;
  Future<void>? _accessPointsStarted;

  WifiDeviceController(
    super.client,
    super.path, {
    super.serviceName = 'org.jappeos.Core',
  }) : wifiProxy = WifiDeviceProxy(client, path, serviceName: serviceName) {
    _accessPoints = DbusObjectCollection(
      object: wifiProxy.object,
      interface: WifiDeviceProxy.interface,
      addedSignal: 'AccessPointAdded',
      removedSignal: 'AccessPointRemoved',
      enumerate:
          (object) async =>
              (await object.getProperty(
                WifiDeviceProxy.interface,
                'AccessPoints',
                signature: DBusSignature('ao'),
              )).asObjectPathArray().toList(),
      createController:
          (path, owner) =>
              WifiAccessPointController(client, path, serviceName: owner),
      onChanged: () {
        final device = current;
        if (device != null && !isDisposed) {
          emit(device.copyWith(accessPoints: _accessPoints.values));
        }
      },
      onError: (error, stack) {
        if (!isDisposed) log.warning('Access point watch failed', error, stack);
      },
    );
  }

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

      final res = await wifiProxy
          .connectResult()
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
      throw WifiConnectException(
        "Timed out while waiting for connection result",
      );
    }
  }

  /// Disconnects from a Wi-Fi network. Throws on failure.
  Future<void> disconnect() async {
    await wifiProxy.disconnect();
  }

  // Initial load

  @override
  Future<NetworkWifiDevice> loadDeviceSnapshot() async {
    await (_accessPointsStarted ??= _accessPoints.start());

    return NetworkWifiDevice(
      path: path,
      id: await deviceProxy.id,
      type: NetworkDeviceType.wifi,
      state:
          NetworkDeviceState.values.byNameOrNull(await deviceProxy.state) ??
          NetworkDeviceState.unknown,
      hwAddress: await deviceProxy.hwAddress,
      managed: await deviceProxy.managed,
      activeConnection: current?.activeConnection,
      accessPoints: _accessPoints.values,
    );
  }

  @override
  void dispose() {
    _accessPoints.dispose();
    super.dispose();
  }
}

class WifiAuthException implements Exception {}

class WifiConnectException implements Exception {
  final String message;

  WifiConnectException(this.message);
}
