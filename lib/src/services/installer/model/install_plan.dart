import 'package:dbus/dbus.dart';

import 'storage_info.dart';

class InstallPlan {
  final String hostname;
  final String username;
  final String password;
  final String timezone;
  final String locale;
  final (String, String) keyboardLayout;
  final InstallDiskInfo disk;
  final bool installProprietary;
  final bool installRecommendedDrivers;

  InstallPlan({
    required this.hostname,
    required this.username,
    required this.password,
    required this.timezone,
    required this.locale,
    required this.keyboardLayout,
    required this.disk,
    required this.installProprietary,
    required this.installRecommendedDrivers,
  });
}

class InstallPlanResult {
  final int planId;
  final List<String> warnings;

  InstallPlanResult({
    required this.planId,
    required this.warnings,
  });
}

class InstallDiskInfo {
  final String device;
  final InstallDiskMode mode;
  final List<InstallDiskMountInfo> mounts;
  final List<InstallDiskOperationInfo> operations;

  InstallDiskInfo({
    required this.device,
    required this.mode,
    this.mounts = const [],
    this.operations = const [],
  }) : assert(
          (mode == InstallDiskMode.erase && mounts.isEmpty && operations.isEmpty) ||
              (mode == InstallDiskMode.manual && mounts.isNotEmpty && operations.isEmpty) ||
              (mode == InstallDiskMode.custom && mounts.isEmpty && operations.isNotEmpty),
          'Invalid disk info for the selected mode',
        );

  factory InstallDiskInfo.erase(String device) => InstallDiskInfo(
        device: device,
        mode: InstallDiskMode.erase,
      );

  factory InstallDiskInfo.manual(
    String device,
    List<InstallDiskMountInfo> mounts) => InstallDiskInfo(
        device: device,
        mode: InstallDiskMode.manual,
        mounts: mounts,
      );

  factory InstallDiskInfo.custom(
    String device,
    List<InstallDiskOperationInfo> operations) => InstallDiskInfo(
        device: device,
        mode: InstallDiskMode.custom,
        operations: operations,
      );
}

class InstallDiskMountInfo {
  final String partition;
  final String mountPoint;

  InstallDiskMountInfo({
    required this.partition,
    required this.mountPoint,
  }) : assert(
          mountPoint == kStorageMountpointBoot || mountPoint == kStorageMountpointRoot,
          'Invalid mount point: $mountPoint',
        );
}

abstract class InstallDiskOperationInfo {
  final InstallDiskOperationType type;

  InstallDiskOperationInfo({
    required this.type,
  });

  Map<String, DBusValue> toMap();
}

class InstallDiskOperationCreateInfo extends InstallDiskOperationInfo {
  final String region;
  final int sizeMiB;
  final bool remaining;
  final StorageFilesystemType filesystem;
  final String mountPoint;

  InstallDiskOperationCreateInfo({
    required this.region,
    this.sizeMiB = 0,
    required this.remaining,
    required this.filesystem,
    required this.mountPoint,
  }) : assert(
          (remaining && sizeMiB == 0) || (!remaining && sizeMiB > 0),
          'Size must be greater than 0 if not using remaining space',
        ), assert(
          mountPoint == kStorageMountpointBoot ||
          mountPoint == kStorageMountpointRoot ||
          mountPoint.isEmpty,
          'Invalid mount point: $mountPoint',
        ), super(type: InstallDiskOperationType.create);

  factory InstallDiskOperationCreateInfo.specificSize(
    String region,
    int sizeMiB,
    StorageFilesystemType filesystem,
    String mountPoint) => InstallDiskOperationCreateInfo(
        region: region,
        sizeMiB: sizeMiB,
        remaining: false,
        filesystem: filesystem,
        mountPoint: mountPoint,
      );

  factory InstallDiskOperationCreateInfo.remaining(
    String region,
    StorageFilesystemType filesystem,
    String mountPoint) => InstallDiskOperationCreateInfo(
        region: region,
        remaining: true,
        filesystem: filesystem,
        mountPoint: mountPoint,
      );

  @override
  Map<String, DBusValue> toMap() {
    return {
      'region': DBusString(region),
      'sizeMiB': DBusUint64(sizeMiB),
      'remaining': DBusBoolean(remaining),
      'filesystem': DBusString(filesystem.name),
      'mountpoint': DBusString(mountPoint),
    };
  }
}

class InstallDiskOperationResizeInfo extends InstallDiskOperationInfo {
  final String partition;
  final int sizeMiB;
  final bool remaining;

  InstallDiskOperationResizeInfo({
    required this.partition,
    this.sizeMiB = 0,
    required this.remaining,
  }) : assert(
          (remaining && sizeMiB == 0) || (!remaining && sizeMiB > 0),
          'Size must be greater than 0 if not using remaining space',
        ), super(type: InstallDiskOperationType.resize);

  factory InstallDiskOperationResizeInfo.specificSize(
    String partition,
    int sizeMiB) => InstallDiskOperationResizeInfo(
        partition: partition,
        sizeMiB: sizeMiB,
        remaining: false,
      );

  factory InstallDiskOperationResizeInfo.remaining(
    String partition) => InstallDiskOperationResizeInfo(
        partition: partition,
        remaining: true,
      );

  @override
  Map<String, DBusValue> toMap() {
    return {
      'partition': DBusString(partition),
      'sizeMiB': DBusUint64(sizeMiB),
      'remaining': DBusBoolean(remaining),
    };
  }
}

class InstallDiskOperationRemoveInfo extends InstallDiskOperationInfo {
  final String partition;

  InstallDiskOperationRemoveInfo({
    required this.partition,
  }) : super(type: InstallDiskOperationType.remove);

  @override
  Map<String, DBusValue> toMap() {
    return {
      'partition': DBusString(partition),
    };
  }
}

class InstallDiskOperationSetMountpointInfo extends InstallDiskOperationInfo {
  final String partition;
  final String mountPoint;

  InstallDiskOperationSetMountpointInfo({
    required this.partition,
    required this.mountPoint,
  }) : assert(
          mountPoint == kStorageMountpointBoot ||
          mountPoint == kStorageMountpointRoot ||
          mountPoint.isEmpty,
          'Invalid mount point: $mountPoint',
        ), super(type: InstallDiskOperationType.setMountpoint);

  @override
  Map<String, DBusValue> toMap() {
    return {
      'partition': DBusString(partition),
      'mountpoint': DBusString(mountPoint),
    };
  }
}

class InstallDiskOperationSetFilesystemInfo extends InstallDiskOperationInfo {
  final String partition;
  final StorageFilesystemType filesystem;

  InstallDiskOperationSetFilesystemInfo({
    required this.partition,
    required this.filesystem,
  }) : super(type: InstallDiskOperationType.setFilesystem);

  @override
  Map<String, DBusValue> toMap() {
    return {
      'partition': DBusString(partition),
      'filesystem': DBusString(filesystem.name),
    };
  }
}

enum InstallDiskMode {
  erase,
  manual,
  custom,
}

enum InstallDiskOperationType {
  create,
  resize,
  remove,
  setMountpoint,
  setFilesystem,
}