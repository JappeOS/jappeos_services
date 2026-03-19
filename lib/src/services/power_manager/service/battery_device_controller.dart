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

    if (changed.containsKey(BatteryDeviceProxy.kId)) {
      id = changed[BatteryDeviceProxy.kId]!.asString();
    }
    if (changed.containsKey(BatteryDeviceProxy.kType)) {
      type =
          BatteryDeviceType.values.byNameOrNull(changed[BatteryDeviceProxy.kType]!.asString())
          ?? BatteryDeviceType.unknown;
    }
    if (changed.containsKey(BatteryDeviceProxy.kPowerSupply)) {
      isPowerSupply = changed[BatteryDeviceProxy.kPowerSupply]!.asBoolean();
    }
    if (changed.containsKey(BatteryDeviceProxy.kIsPresent)) {
      isPresent = changed[BatteryDeviceProxy.kIsPresent]!.asBoolean();
    }
    if (changed.containsKey(BatteryDeviceProxy.kState)) {
      state =
          BatteryDeviceState.values.byNameOrNull(changed[BatteryDeviceProxy.kState]!.asString())
          ?? BatteryDeviceState.unknown;
    }
    if (changed.containsKey(BatteryDeviceProxy.kChargePercentage)) {
      chargePercentage = changed[BatteryDeviceProxy.kChargePercentage]!.asDouble();
    }
    if (changed.containsKey(BatteryDeviceProxy.kTimeToEmpty)) {
      timeToEmpty = Duration(seconds: changed[BatteryDeviceProxy.kTimeToEmpty]!.asInt64());
    }
    if (changed.containsKey(BatteryDeviceProxy.kTimeToFull)) {
      timeToFull = Duration(seconds: changed[BatteryDeviceProxy.kTimeToFull]!.asInt64());
    }

    if (id == null &&
        type == null &&
        isPowerSupply == null &&
        isPresent == null &&
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
      isPresent: isPresent,
      state: state,
      chargePercentage: chargePercentage,
      timeToEmpty: timeToEmpty,
      timeToFull: timeToFull,
    );
  }
}