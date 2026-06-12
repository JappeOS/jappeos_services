import 'package:dbus/dbus.dart';
import 'package:logging/logging.dart';

import '../../../extensions.dart';
import '../../../logger.dart';
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
  bool _initialized = false;
  late final InstallerServiceProxy _proxy;

  late InstallState _state;
  late String _errorMessage;
  late InstallProgress _progress;
  late String _currentLocale;
  late String _currentTimezone;
  late (String, String) _currentKeyboardLayout;

  final List<StreamSubscription> _subs = [];

  InstallerService() : super(ServiceType.system) {
    _proxy = InstallerServiceProxy(client);
    scheduleMicrotask(() => init());
  }

  InstallState get state => _state;
  String get errorMessage => _errorMessage;
  InstallProgress get progress => _progress;
  String get currentLocale => _currentLocale;
  String get currentTimezone => _currentTimezone;
  (String, String) get currentKeyboardLayout => _currentKeyboardLayout;

  // Init

  Future<void> init() async {
    if (_initialized || !mounted) return;
    _initialized = true;

    try {
      _state = await _proxy.state.then(
          (s) => InstallState.values.byNameOrNull(s) ?? InstallState.idle);
      _errorMessage = await _proxy.errorMessage;
      _progress = await _proxy.progress.then((p) => InstallProgress(
            p.$1,
            p.$2,
            p.$3,
          ));
      _currentLocale = await _proxy.currentLocale;
      _currentTimezone = await _proxy.currentTimezone;
      _currentKeyboardLayout = await _proxy.currentKeyboardLayout;
      _subscribeSignals();
    } catch (e, st) {
      log.severe('InstallerService init failed', e, st);
    }
  }

  // Cleanup

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  // Service methods

  Future<LocaleInfo> getLocaleInfo() async {
    final info = await _proxy.getLocaleInfo();
    return LocaleInfo(
      locales: info.$1,
      timezones: info.$2,
      keyboardLayouts: KeyboardLayoutInfo(
        layouts: (info.$3).map((k, v) => MapEntry(
              k,
              KeyboardLayout(
                id: v.$1,
                variants: v.$2,
              ),
            )),
      ),
    );
  }

  Future<StorageInfo> getStorageInfo() async {
    final info = await _proxy.getStorageInfo();
    return StorageInfo(
      devices: info.map((k, v) => MapEntry(
            k,
            StorageDeviceInfo(
              device: k,
              sizeMiB: v.$1,
              partitions: v.$2.map((p) => StoragePartitionInfo(
                    device: p.$1,
                    filesystem: StorageFilesystemType.values.byNameOrNull(p.$2)
                        ?? StorageFilesystemType.unknown,
                    sizeMiB: p.$3,
                    mountPoint: p.$4,
                  )).toList(),
          ))),
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
        plan.disk.mounts
            .map((m) => (m.partition, m.mountPoint))
            .toList(),
        plan.disk.operations
            .map((o) => (
              o.type.index,
              o.toMap().map((k, v) => MapEntry(k, DBusVariant(v)))
            ))
            .toList(),
      ),
      plan.installProprietary,
      plan.installRecommendedDrivers,
    );

    return InstallPlanResult(
      planId: reply.$1,
      warnings: reply.$2,
    );
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

  // Signal subscriptions

  void _subscribeSignals() {
    _subs.add(
      _proxy.propertiesChanged().listen((props) {
        final changed = props.changedProperties;
        String? state;
        String? errorMessage;
        (String, double, String)? progress;
        String? currentLocale;
        String? currentTimezone;
        (String, String)? currentKeyboardLayout;

        if (changed.containsKey(InstallerServiceProxy.kState)) {
          state = changed[InstallerServiceProxy.kState]!.asString();
        }
        if (changed.containsKey(InstallerServiceProxy.kErrorMessage)) {
          errorMessage = changed[InstallerServiceProxy.kErrorMessage]!.asString();
        }
        if (changed.containsKey(InstallerServiceProxy.kProgress)) {
          progress = changed[InstallerServiceProxy.kProgress]!.asStruct().length == 3
              ? (
                  (changed[InstallerServiceProxy.kProgress]!
                      .asStruct()[0] as DBusString).value,
                  (changed[InstallerServiceProxy.kProgress]!
                      .asStruct()[1] as DBusDouble).value,
                  (changed[InstallerServiceProxy.kProgress]!
                      .asStruct()[2] as DBusString).value,
                )
              : null;
        }
        if (changed.containsKey(InstallerServiceProxy.kCurrentLocale)) {
          currentLocale
              = changed[InstallerServiceProxy.kCurrentLocale]!.asString();
        }
        if (changed.containsKey(InstallerServiceProxy.kCurrentTimezone)) {
          currentTimezone
              = changed[InstallerServiceProxy.kCurrentTimezone]!.asString();
        }
        if (changed.containsKey(InstallerServiceProxy.kCurrentKeyboardLayout)) {
          currentKeyboardLayout
              = changed[InstallerServiceProxy.kCurrentKeyboardLayout]!.asStruct().length == 2
                  ? (
                      (changed[InstallerServiceProxy.kCurrentKeyboardLayout]!
                          .asStruct()[0] as DBusString).value,
                      (changed[InstallerServiceProxy.kCurrentKeyboardLayout]!
                          .asStruct()[1] as DBusString).value,
                    )
                  : null;
        }

        if (state == null &&
            errorMessage == null &&
            progress == null &&
            currentLocale == null &&
            currentTimezone == null &&
            currentKeyboardLayout == null) {
          return;
        }

        if (state != null) {
          _state = InstallState.values.byNameOrNull(state) ?? InstallState.idle;
        }
        if (errorMessage != null) {
          _errorMessage = errorMessage;
        }
        if (progress != null) {
          _progress = InstallProgress(
            progress.$1,
            progress.$2,
            progress.$3,
          );
        }
        if (currentLocale != null) {
          _currentLocale = currentLocale;
        }
        if (currentTimezone != null) {
          _currentTimezone = currentTimezone;
        }
        if (currentKeyboardLayout != null) {
          _currentKeyboardLayout = currentKeyboardLayout;
        }

        notifyListeners();
      }),
    );
  }
}
