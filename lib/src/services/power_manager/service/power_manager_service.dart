import 'dart:async';

import 'package:dbus/dbus.dart';
import 'package:logging/logging.dart';

import '../../../logger.dart';
import '../../../utils/dbus/object_collection.dart';
import '../../service.dart';
import '../dbus/power_manager_service_proxy.dart';
import '../model/battery_device.dart';
import 'battery_device_controller.dart';

class PowerManagerService extends Service {
  final Logger log = createLogger('PowerManagerService');
  late final PowerManagerServiceProxy _proxy;
  late final DbusObjectCollection<BatteryDevice, BatteryDeviceController>
  _collection;
  Future<void>? _initializing;

  PowerManagerService() : super(ServiceType.system) {
    _proxy = PowerManagerServiceProxy(client);
    _collection = DbusObjectCollection(
      object: _proxy.object,
      interface: PowerManagerServiceProxy.interface,
      addedSignal: 'BatteryDeviceAdded',
      removedSignal: 'BatteryDeviceRemoved',
      enumerate:
          (object) async =>
              (await object.callMethod(
                PowerManagerServiceProxy.interface,
                'ListBatteryDevices',
                [],
                replySignature: DBusSignature('ao'),
              )).returnValues[0].asObjectPathArray().toList(),
      createController:
          (path, owner) =>
              BatteryDeviceController(client, path, serviceName: owner),
      onChanged: notifyListeners,
      onError:
          (error, stack) => log.severe('Device watch failed', error, stack),
    );
    scheduleMicrotask(init);
  }

  List<BatteryDevice> get devices => _collection.values;

  Future<void> init() => _initializing ??= _start();

  Future<void> _start() async {
    if (!mounted) return;
    try {
      await _collection.start();
    } catch (error, stack) {
      _initializing = null;
      if (mounted) log.severe('PowerManagerService init failed', error, stack);
    }
  }

  @override
  void dispose() {
    _collection.dispose();
    super.dispose();
  }

  // Service methods

  /// Tries to shut down the system. Throws on failure.
  Future<void> shutdown() async => await _proxy.shutdown();

  /// Tries to reboot the system. Throws on failure.
  Future<void> reboot() async => await _proxy.reboot();

  /// Tries to suspend the system. Throws on failure.
  Future<void> suspend() async => await _proxy.suspend();
}
