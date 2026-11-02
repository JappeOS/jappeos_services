import 'dart:async';

import 'package:dbus/dbus.dart';
import 'package:logging/logging.dart';

import '../../extensions.dart';
import '../../logger.dart';
import 'signals.dart';
import 'watched_snapshot.dart';

/// Model adapter for one remote object. Its owning collection recreates it
/// when the destination changes owner; the object is pinned to that owner.
abstract class DbusObjectController<T> {
  final DBusClient client;
  final DBusObjectPath path;
  final String serviceName;
  late final Logger log = createLogger(
    'DbusObjCtrl@${path.shortenForDisplay()}',
  );

  T? _current;
  T? get current => _current;
  bool _disposed = false;
  bool get isDisposed => _disposed;
  void Function(T)? _onUpdate;
  WatchedSnapshot<T, DBusPropertiesChangedSignal>? _snapshot;

  DbusObjectController(this.client, this.path, {required this.serviceName});

  Future<T> loadInitial();
  T applyChanges(T current, Map<String, DBusValue> changed);
  String get interfaceName;

  Future<T> load() {
    if (_disposed) return Future.error(StateError('Controller is disposed'));

    _snapshot ??= WatchedSnapshot(
      read: loadInitial,
      changes: dbusPropertiesChanged(
        DBusRemoteObject(client, name: serviceName, path: path),
        interface: interfaceName,
      ),
      beforeRead: () => dbusSignalBarrier(client),
      requiresReload: (event) => event.invalidatedProperties.isNotEmpty,
      reduce:
          (current, event) => applyChanges(current, event.changedProperties),
      onData: (value) {
        final old = _current;
        emit(value);
        if (old != null && !_disposed) onAfterUpdate(old, value);
      },
      onError:
          (error, stack) => log.severe('Property watch failed', error, stack),
    );

    return _snapshot!.load();
  }

  void watch(void Function(T) onUpdate) => _onUpdate = onUpdate;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _onUpdate = null;
    unawaited(_snapshot?.close());
  }

  void onAfterUpdate(T old, T updated) {}

  void emit(T updated) {
    if (_disposed) return;
    _current = updated;
    _snapshot?.setCurrent(updated);
    _onUpdate?.call(updated);
  }
}
