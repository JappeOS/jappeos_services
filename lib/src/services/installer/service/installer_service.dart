import 'package:dbus/dbus.dart';
import 'package:logging/logging.dart';

import '../../../extensions.dart';
import '../../../logger.dart';
import '../../../utils/dbus/property_watcher.dart';
import '../../service.dart';

import 'dart:async';

import '../dbus/installer_service_proxy.dart';
import '../model/install_plan.dart';
import '../model/install_progress.dart';
import '../model/install_state.dart';
import '../model/locale_info.dart';
import '../model/storage_info.dart';

class InstallerService extends Service {
  final Logger log = createLogger('InstallerService');
  Future<void>? _initializing;
  late final InstallerServiceProxy _proxy;

  InstallState _state = InstallState.idle;
  String _errorMessage = '';
  InstallProgress _progress = InstallProgress('', 0, '');
  String _currentLocale = '';
  String _currentTimezone = '';
  (String, String) _currentKeyboardLayout = ('', '');

  late final DbusPropertyWatcher _properties;

  InstallerService() : super(ServiceType.system) {
    _proxy = InstallerServiceProxy(client);
    _properties = DbusPropertyWatcher(
      object: _proxy.object,
      interface: InstallerServiceProxy.interface,
      onChanged: _applyProperties,
      onUnavailable: () {
        _state = InstallState.idle;
        _errorMessage = '';
        _progress = InstallProgress('', 0, '');
        _currentLocale = '';
        _currentTimezone = '';
        _currentKeyboardLayout = ('', '');
        notifyListeners();
      },
      onError: (error, stack) {
        if (mounted) log.severe('Installer watch failed', error, stack);
      },
    );
    scheduleMicrotask(init);
  }

  InstallState get state => _state;
  String get errorMessage => _errorMessage;
  InstallProgress get progress => _progress;
  String get currentLocale => _currentLocale;
  String get currentTimezone => _currentTimezone;
  (String, String) get currentKeyboardLayout => _currentKeyboardLayout;

  // Init

  Future<void> init() => _initializing ??= _start();

  Future<void> _start() async {
    if (!mounted) return;
    try {
      await _properties.start();
    } catch (error, stack) {
      _initializing = null;
      if (mounted) log.severe('InstallerService init failed', error, stack);
    }
  }

  @override
  void dispose() {
    _properties.dispose();
    super.dispose();
  }

  // Service methods

  Future<LocaleInfo> getLocaleInfo() async {
    final info = await _proxy.getLocaleInfo();
    return LocaleInfo(
      locales: info.$1,
      timezones: info.$2,
      keyboardLayouts: KeyboardLayoutInfo(
        layouts: (info.$3).map(
          (k, v) => MapEntry(k, KeyboardLayout(id: v.$1, variants: v.$2)),
        ),
      ),
    );
  }

  Future<StorageInfo> getStorageInfo() async {
    final info = await _proxy.getStorageInfo();
    return StorageInfo(
      devices: info.map(
        (k, v) => MapEntry(
          k,
          StorageDeviceInfo(
            device: k,
            sizeMiB: v.$1,
            partitions:
                v.$2
                    .map(
                      (p) => StoragePartitionInfo(
                        device: p.$1,
                        filesystem:
                            p.$2.isEmpty
                                ? StorageFilesystemType.freeSpace
                                : (StorageFilesystemType.values.byNameOrNull(
                                      p.$2,
                                    ) ??
                                    StorageFilesystemType.unknown),
                        sizeMiB: p.$3,
                        mountPoint: p.$4,
                      ),
                    )
                    .toList(),
          ),
        ),
      ),
    );
  }

  Future<InstallPlanResult> createInstallPlan(InstallPlan plan) async {
    final reply = await _proxy.createInstallPlan(
      plan.hostname,
      plan.username,
      plan.password,
      plan.timezone,
      plan.locale,
      plan.keyboardLayout,
      (
        plan.disk.device,
        plan.disk.mode.index,
        plan.disk.mounts.map((m) => (m.partition, m.mountPoint)).toList(),
        plan.disk.operations
            .map(
              (o) => (
                o.type.index,
                o.toMap().map((k, v) => MapEntry(k, DBusVariant(v))),
              ),
            )
            .toList(),
      ),
      plan.installProprietary,
      plan.installRecommendedDrivers,
    );

    return InstallPlanResult(planId: reply.$1, warnings: reply.$2);
  }

  Future<void> cancelInstallPlan(int planId) =>
      _proxy.cancelInstallPlan(planId);

  Future<void> beginInstallation(int planId) =>
      _proxy.beginInstallation(planId);

  Future<bool> verifyUsername(String username) =>
      _proxy.verifyUsername(username);

  Future<bool> verifyHostname(String hostname) =>
      _proxy.verifyHostname(hostname);

  Future<void> setCurrentLocale(String locale) =>
      _proxy.setCurrentLocale(locale);

  Future<void> setCurrentTimezone(String timezone) =>
      _proxy.setCurrentTimezone(timezone);

  Future<void> setCurrentKeyboardLayout((String, String) layout) =>
      _proxy.setCurrentKeyboardLayout(layout);

  // The watcher supplies a full cache, including reloaded invalidated values.
  void _applyProperties(Map<String, DBusValue> properties) {
    _state =
        InstallState.values.byNameOrNull(
          properties[InstallerServiceProxy.kState]?.asString() ?? '',
        ) ??
        InstallState.idle;

    _errorMessage =
        properties[InstallerServiceProxy.kErrorMessage]?.asString() ?? '';

    final progress = properties[InstallerServiceProxy.kProgress]?.asStruct();
    _progress =
        progress != null && progress.length == 3
            ? InstallProgress(
              progress[0].asString(),
              progress[1].asDouble(),
              progress[2].asString(),
            )
            : InstallProgress('', 0, '');

    _currentLocale =
        properties[InstallerServiceProxy.kCurrentLocale]?.asString() ?? '';
    _currentTimezone =
        properties[InstallerServiceProxy.kCurrentTimezone]?.asString() ?? '';

    final layout =
        properties[InstallerServiceProxy.kCurrentKeyboardLayout]?.asStruct();
    _currentKeyboardLayout =
        layout != null && layout.length == 2
            ? (layout[0].asString(), layout[1].asString())
            : ('', '');

    notifyListeners();
  }
}
