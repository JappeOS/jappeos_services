import 'package:dbus/dbus.dart';
import 'package:logging/logging.dart';

import '../../../logger.dart';
import '../../../utils/dbus/object_collection.dart';
import '../../../utils/dbus/property_watcher.dart';
import '../../service.dart';
import '../dbus/battery_device_proxy.dart';
import '../dbus/logind_proxy.dart';
import '../dbus/upower_proxy.dart';
import '../model/battery_device.dart';
import '../model/power_action_capability.dart';
import 'battery_device_controller.dart';

class PowerManagerService extends Service {
  final Logger log = createLogger('PowerManagerService');
  late final UPowerProxy _upower;
  late final LogindProxy _logind;
  late final DbusPropertyWatcher _displayWatcher;
  BatteryDevice? _displayDevice;
  late final DbusObjectCollection<BatteryDevice, BatteryDeviceController>
  _collection;

  /// [busClient], when supplied, is borrowed and must connect to a system bus.
  PowerManagerService({DBusClient? busClient})
    : super(ServiceType.system, client: busClient) {
    _upower = UPowerProxy(client);
    _logind = LogindProxy(client);

    _collection = DbusObjectCollection(
      object: _upower.object,
      interface: UPowerProxy.interface,
      addedSignal: 'DeviceAdded',
      removedSignal: 'DeviceRemoved',
      enumerate: UPowerProxy.enumerateDevices,
      createController:
          (path, owner) =>
              BatteryDeviceController(client, path, serviceName: owner),
      onChanged: notifyListeners,
      onError:
          (error, stack) => log.severe('Device watch failed', error, stack),
    );

    _displayWatcher = DbusPropertyWatcher(
      object: DBusRemoteObject(
        client,
        name: UPowerProxy.destination,
        path: UPowerProxy.displayDevicePath,
      ),
      interface: BatteryDeviceProxy.interface,
      onChanged: (properties) {
        final device = BatteryDeviceController.fromProperties(properties);
        _displayDevice = device.isPresent ? device : null;
        notifyListeners();
      },
      onUnavailable: () {
        _displayDevice = null;
        notifyListeners();
      },
      onError:
          (error, stack) =>
              log.severe('Display device watch failed', error, stack),
    );

    initializeResources([_collection.resource, _displayWatcher.resource]);
  }

  List<BatteryDevice> get devices => _collection.values;

  /// UPower's composite status device; null when unavailable or not present.
  /// Kept separate from [devices] to avoid double-counting physical batteries.
  BatteryDevice? get displayDevice => _displayDevice;

  @override
  void dispose() {
    _displayWatcher.dispose();
    _collection.dispose();
    super.dispose();
  }

  /// Requests shutdown. Errors (including policy/inhibitor refusals) propagate.
  /// Optionally allows interactive authentication.
  Future<void> shutdown({bool interactive = false}) =>
      _logind.shutdown(interactive: interactive);

  /// Requests reboot, optionally allowing interactive authentication.
  Future<void> reboot({bool interactive = false}) =>
      _logind.reboot(interactive: interactive);

  /// Requests suspend, optionally allowing interactive authentication.
  Future<void> suspend({bool interactive = false}) =>
      _logind.suspend(interactive: interactive);

  /// Requests hibernation; support depends on the system's sleep configuration.
  /// Optionally allows interactive authentication.
  Future<void> hibernate({bool interactive = false}) =>
      _logind.hibernate(interactive: interactive);

  // Capability checks that do not guarantee a subsequent action.
  Future<PowerActionCapability> canShutdown() => _logind.canShutdown();
  Future<PowerActionCapability> canReboot() => _logind.canReboot();
  Future<PowerActionCapability> canSuspend() => _logind.canSuspend();
  Future<PowerActionCapability> canHibernate() => _logind.canHibernate();
}
