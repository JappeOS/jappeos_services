import 'package:dbus/dbus.dart';

import '../../../dbus_object_controller.dart';
import '../../../extensions.dart';
import '../dbus/battery_device_proxy.dart';
import '../model/battery_device.dart';

class BatteryDeviceController extends DbusObjectController<BatteryDevice> {
  final BatteryDeviceProxy _proxy;

  BatteryDeviceController(super.client, super.path)
      : _proxy = BatteryDeviceProxy(client, path);

  @override
  String get interfaceName => BatteryDeviceProxy.interface;

  @override
  Future<BatteryDevice> loadInitial() async {
    return BatteryDevice(
      id: await _proxy.id,
      type: BatteryDeviceType.values.byNameOrNull(
            await _proxy.type,
          ) ??
          BatteryDeviceType.unknown,
      isPowerSupply: await _proxy.powerSupply,
      isPresent: await _proxy.isPresent,
      state: BatteryDeviceState.values.byNameOrNull(
            await _proxy.state,
          ) ??
          BatteryDeviceState.unknown,
      chargePercentage: await _proxy.chargePercentage,
      timeToEmpty: Duration(seconds: await _proxy.timeToEmpty),
      timeToFull: Duration(seconds: await _proxy.timeToFull),
    );
  }

  @override
  BatteryDevice applyChanges(
    BatteryDevice current,
    Map<String, DBusValue> changed,
  ) {
    String? id;
    BatteryDeviceType? type;
    bool? isPowerSupply;
    bool? isPresent;
    BatteryDeviceState? state;
    double? chargePercentage;
    Duration? timeToEmpty;
    Duration? timeToFull;

    if (changed.containsKey('Id')) {
      id = changed['Id']!.asString();
    }
    if (changed.containsKey('Type')) {
      type =
          BatteryDeviceType.values.byNameOrNull(changed['Type']!.asString())
          ?? BatteryDeviceType.unknown;
    }
    if (changed.containsKey('PowerSupply')) {
      isPowerSupply = changed['PowerSupply']!.asBoolean();
    }
    if (changed.containsKey('IsPresent')) {
      isPresent = changed['IsPresent']!.asBoolean();
    }
    if (changed.containsKey('State')) {
      state =
          BatteryDeviceState.values.byNameOrNull(changed['State']!.asString())
          ?? BatteryDeviceState.unknown;
    }
    if (changed.containsKey('ChargePercentage')) {
      chargePercentage = changed['ChargePercentage']!.asDouble();
    }
    if (changed.containsKey('TimeToEmpty')) {
      timeToEmpty = Duration(seconds: changed['TimeToEmpty']!.asInt64());
    }
    if (changed.containsKey('TimeToFull')) {
      timeToFull = Duration(seconds: changed['TimeToFull']!.asInt64());
    }

    if (id == null &&
        type == null &&
        isPowerSupply == null &&
        state == null &&
        chargePercentage == null &&
        timeToEmpty == null &&
        timeToFull == null) {
      return current;
    }

    return current.copyWith(
      id: id,
      type: type,
      isPowerSupply: isPowerSupply,
      state: state,
      chargePercentage: chargePercentage,
      timeToEmpty: timeToEmpty,
      timeToFull: timeToFull,
    );
  }
}