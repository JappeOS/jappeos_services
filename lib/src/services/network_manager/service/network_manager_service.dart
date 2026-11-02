import 'package:dbus/dbus.dart';
import 'package:logging/logging.dart';

import '../../../logger.dart';
import '../../../utils/dbus/object_collection.dart';
import '../../service.dart';

import 'dart:async';

import '../dbus/device_proxy.dart';
import '../dbus/network_manager_service_proxy.dart';
import '../model/network_device.dart';
import '../model/wifi_access_point.dart';
import 'network_device_controller.dart';

class NetworkManagerService extends Service {
  final Logger log = createLogger('NetworkManagerService');
  late final NetworkManagerServiceProxy _proxy;
  late final DbusObjectCollection<
    NetworkDevice,
    NetworkDeviceControllerBase<NetworkDevice>
  >
  _collection;
  Future<void>? _initializing;

  NetworkManagerService() : super(ServiceType.system) {
    _proxy = NetworkManagerServiceProxy(client);
    _collection = DbusObjectCollection(
      object: _proxy.object,
      interface: NetworkManagerServiceProxy.interface,
      addedSignal: 'DeviceAdded',
      removedSignal: 'DeviceRemoved',
      enumerate:
          (object) async =>
              (await object.callMethod(
                NetworkManagerServiceProxy.interface,
                'ListDevices',
                [],
                replySignature: DBusSignature('ao'),
              )).returnValues[0].asObjectPathArray().toList(),
      createController: _createController,
      onChanged: notifyListeners,
      onError:
          (error, stack) => log.severe('Device watch failed', error, stack),
    );
    scheduleMicrotask(init);
  }

  List<NetworkDevice> get devices => _collection.values;
  List<NetworkWifiDevice> get wifiDevices =>
      devices.whereType<NetworkWifiDevice>().toList(growable: false);
  List<NetworkDevice> get ethernetDevices =>
      devices.where((d) => d.isEthernet).toList(growable: false);

  Future<void> init() => _initializing ??= _start();

  Future<void> _start() async {
    if (!mounted) return;
    try {
      await _collection.start();
    } catch (error, stack) {
      _initializing = null;
      if (mounted) {
        log.severe('NetworkManagerService init failed', error, stack);
      }
    }
  }

  @override
  void dispose() {
    _collection.dispose();
    super.dispose();
  }

  // Service methods

  Future<void> setEnabled(NetworkDevice device, bool enabled) async {
    final controller = _collection.controller(device.path);
    await controller!.setEnabled(enabled);
  }

  Future<void> scanWifi(NetworkDevice device) async {
    final controller = _collection.controller(device.path);
    if (controller is WifiDeviceController) {
      await controller.scan();
      return;
    }
    throw ArgumentError('Device is not a WiFi device');
  }

  Future<void> connectWifi(
    NetworkDevice device,
    WifiAccessPoint ap, [
    String secret = "",
  ]) async {
    final controller = _collection.controller(device.path);
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
    final controller = _collection.controller(device.path);
    if (controller is WifiDeviceController) {
      await controller.disconnect();
      return;
    }
    throw ArgumentError('Device is not a WiFi device');
  }

  Future<NetworkDeviceControllerBase<NetworkDevice>> _createController(
    DBusObjectPath path,
    String owner,
  ) async {
    final proxy = DeviceProxy(client, path, serviceName: owner);
    return await proxy.type == 'wifi'
        ? WifiDeviceController(client, path, serviceName: owner)
        : NetworkDeviceController(client, path, serviceName: owner);
  }
}
