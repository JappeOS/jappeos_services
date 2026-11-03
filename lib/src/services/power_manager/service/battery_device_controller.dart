import 'package:dbus/dbus.dart';

import '../../../utils/dbus/object_controller.dart';
import '../dbus/battery_device_proxy.dart';
import '../dbus/upower_proxy.dart';
import '../model/battery_device.dart';

class BatteryDeviceController extends DbusObjectController<BatteryDevice> {
  final BatteryDeviceProxy _proxy;

  BatteryDeviceController(
    super.client,
    super.path, {
    super.serviceName = UPowerProxy.destination,
  }) : _proxy = BatteryDeviceProxy(client, path, serviceName: serviceName);

  @override
  String get interfaceName => BatteryDeviceProxy.interface;

  @override
  Future<BatteryDevice> loadInitial() async =>
      fromProperties(await _proxy.getProperties());

  /// UPower leaves fields unset for devices where they do not apply.
  /// Preserve the existing model's Serial-based ID and zero unknown durations.
  static BatteryDevice fromProperties(Map<String, DBusValue> properties) =>
      BatteryDevice(
        id: properties[BatteryDeviceProxy.kId]?.asString() ?? '',
        type: _type(properties[BatteryDeviceProxy.kType]?.asUint32() ?? 0),
        isPowerSupply:
            properties[BatteryDeviceProxy.kPowerSupply]?.asBoolean() ?? false,
        isPresent:
            properties[BatteryDeviceProxy.kIsPresent]?.asBoolean() ?? false,
        state: _state(properties[BatteryDeviceProxy.kState]?.asUint32() ?? 0),
        chargePercentage:
            properties[BatteryDeviceProxy.kChargePercentage]?.asDouble() ?? 0,
        timeToEmpty: Duration(
          seconds: properties[BatteryDeviceProxy.kTimeToEmpty]?.asInt64() ?? 0,
        ),
        timeToFull: Duration(
          seconds: properties[BatteryDeviceProxy.kTimeToFull]?.asInt64() ?? 0,
        ),
      );

  @override
  BatteryDevice applyChanges(
    BatteryDevice current,
    Map<String, DBusValue> changed,
  ) {
    const keys = {
      BatteryDeviceProxy.kId,
      BatteryDeviceProxy.kType,
      BatteryDeviceProxy.kPowerSupply,
      BatteryDeviceProxy.kIsPresent,
      BatteryDeviceProxy.kState,
      BatteryDeviceProxy.kChargePercentage,
      BatteryDeviceProxy.kTimeToEmpty,
      BatteryDeviceProxy.kTimeToFull,
    };
    if (!changed.keys.any(keys.contains)) return current;
    return current.copyWith(
      id: changed[BatteryDeviceProxy.kId]?.asString(),
      type:
          changed.containsKey(BatteryDeviceProxy.kType)
              ? _type(changed[BatteryDeviceProxy.kType]!.asUint32())
              : null,
      isPowerSupply: changed[BatteryDeviceProxy.kPowerSupply]?.asBoolean(),
      isPresent: changed[BatteryDeviceProxy.kIsPresent]?.asBoolean(),
      state:
          changed.containsKey(BatteryDeviceProxy.kState)
              ? _state(changed[BatteryDeviceProxy.kState]!.asUint32())
              : null,
      chargePercentage:
          changed[BatteryDeviceProxy.kChargePercentage]?.asDouble(),
      timeToEmpty:
          changed.containsKey(BatteryDeviceProxy.kTimeToEmpty)
              ? Duration(
                seconds: changed[BatteryDeviceProxy.kTimeToEmpty]!.asInt64(),
              )
              : null,
      timeToFull:
          changed.containsKey(BatteryDeviceProxy.kTimeToFull)
              ? Duration(
                seconds: changed[BatteryDeviceProxy.kTimeToFull]!.asInt64(),
              )
              : null,
    );
  }

  // Explicit protocol mappings: Dart enum declaration order is not a wire ABI.
  static BatteryDeviceType _type(int value) => switch (value) {
    1 => BatteryDeviceType.linePower,
    2 => BatteryDeviceType.battery,
    3 => BatteryDeviceType.ups,
    4 => BatteryDeviceType.monitor,
    5 => BatteryDeviceType.mouse,
    6 => BatteryDeviceType.keyboard,
    7 => BatteryDeviceType.pda,
    8 => BatteryDeviceType.phone,
    9 => BatteryDeviceType.mediaPlayer,
    10 => BatteryDeviceType.tablet,
    11 => BatteryDeviceType.computer,
    12 => BatteryDeviceType.gamingInput,
    13 => BatteryDeviceType.pen,
    14 => BatteryDeviceType.touchpad,
    15 => BatteryDeviceType.modem,
    16 => BatteryDeviceType.network,
    17 => BatteryDeviceType.headset,
    18 => BatteryDeviceType.speakers,
    19 => BatteryDeviceType.headphones,
    20 => BatteryDeviceType.video,
    21 => BatteryDeviceType.otherAudio,
    22 => BatteryDeviceType.remoteControl,
    23 => BatteryDeviceType.printer,
    24 => BatteryDeviceType.scanner,
    25 => BatteryDeviceType.camera,
    26 => BatteryDeviceType.wearable,
    27 => BatteryDeviceType.toy,
    28 => BatteryDeviceType.bluetoothGeneric,
    _ => BatteryDeviceType.unknown,
  };

  static BatteryDeviceState _state(int value) => switch (value) {
    1 => BatteryDeviceState.charging,
    2 => BatteryDeviceState.discharging,
    3 => BatteryDeviceState.empty,
    4 => BatteryDeviceState.fullyCharged,
    5 => BatteryDeviceState.pendingCharge,
    6 => BatteryDeviceState.pendingDischarge,
    _ => BatteryDeviceState.unknown,
  };
}
