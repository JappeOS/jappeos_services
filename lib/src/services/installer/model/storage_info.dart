const String kStorageMountpointBoot = '/boot';
const String kStorageMountpointRoot = '/';

class StorageInfo {
  final Map<String, StorageDeviceInfo> devices;

  StorageInfo({required this.devices});
}

class StorageDeviceInfo {
  final String device;
  final int sizeMiB;
  final List<StoragePartitionInfo> partitions;

  StorageDeviceInfo({
    required this.device,
    required this.sizeMiB,
    this.partitions = const [],
  });
}

class StoragePartitionInfo {
  final String device;
  final StorageFilesystemType filesystem;
  final int sizeMiB;
  final String mountPoint;

  StoragePartitionInfo({
    required this.device,
    required this.filesystem,
    required this.sizeMiB,
    required this.mountPoint,
  });

  bool isFreeSpace() => filesystem == StorageFilesystemType.freeSpace;
}

enum StorageFilesystemType {
  fat32,
  ext4,
  btrfs,
  xfs,
  freeSpace,
  unknown,
}