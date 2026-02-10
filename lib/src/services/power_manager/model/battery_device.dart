enum BatteryDeviceType {
  linePower,
  battery,
  ups,
  monitor,
  mouse,
  keyboard,
  pda,
  phone,
  mediaPlayer,
  tablet,
  computer,
  gamingInput,
  pen,
  touchpad,
  modem,
  network,
  headset,
  speakers,
  headphones,
  video,
  otherAudio,
  remoteControl,
  printer,
  scanner,
  camera,
  wearable,
  toy,
  bluetoothGeneric,
  unknown,
}

enum BatteryDeviceState {
  charging,
  discharging,
  empty,
  fullyCharged,
  pendingCharge,
  pendingDischarge,
  unknown,
}

class BatteryDevice {
  final String id;
  final BatteryDeviceType type;
  final bool isPowerSupply;
  final bool isPresent;
  final BatteryDeviceState state;
  final double chargePercentage;
  final Duration timeToEmpty;
  final Duration timeToFull;

  BatteryDevice({
    required this.id,
    required this.type,
    required this.isPowerSupply,
    required this.isPresent,
    required this.state,
    required this.chargePercentage,
    required this.timeToEmpty,
    required this.timeToFull,
  });

  BatteryDevice copyWith({
    String? id,
    BatteryDeviceType? type,
    bool? isPowerSupply,
    bool? isPresent,
    BatteryDeviceState? state,
    double? chargePercentage,
    Duration? timeToEmpty,
    Duration? timeToFull,
  }) {
    return BatteryDevice(
      id: id ?? this.id,
      type: type ?? this.type,
      isPowerSupply: isPowerSupply ?? this.isPowerSupply,
      isPresent: isPresent ?? this.isPresent,
      state: state ?? this.state,
      chargePercentage: chargePercentage ?? this.chargePercentage,
      timeToEmpty: timeToEmpty ?? this.timeToEmpty,
      timeToFull: timeToFull ?? this.timeToFull,
    );
  }
}