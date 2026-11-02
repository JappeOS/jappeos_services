import 'dart:async';

import 'package:dbus/dbus.dart';

import 'service_watcher.dart';
import 'signals.dart';
import 'watched_snapshot.dart';

/// Watches one interface's properties, refreshing invalidations with GetAll.
/// A replacement service gets a new cache; replies from its predecessor cannot
/// update the new cache. The owner of this watcher owns the bus connection.
class DbusPropertyWatcher {
  final DBusRemoteObject object;
  final String interface;
  final void Function(Map<String, DBusValue>) onChanged;
  final void Function() onUnavailable;
  final void Function(Object, StackTrace) onError;

  late final DbusServiceWatcher _service = DbusServiceWatcher(
    client: object.client,
    destination: object.name,
    onChanged: _ownerChanged,
    onError: onError,
  );
  WatchedSnapshot<Map<String, DBusValue>, DBusPropertiesChangedSignal>?
  _snapshot;
  Future<void>? _loading;
  bool _disposed = false;

  DbusPropertyWatcher({
    required this.object,
    required this.interface,
    required this.onChanged,
    required this.onUnavailable,
    required this.onError,
  });

  Future<void> start() async {
    if (_disposed) return;
    await _service.start(activate: true);
    await _loading;
  }

  void _ownerChanged(String? owner) {
    unawaited(_snapshot?.close());
    _snapshot = null;
    if (_disposed) return;
    onUnavailable();
    if (owner == null) return;

    final remote = DBusRemoteObject(
      object.client,
      name: owner,
      path: object.path,
    );

    final snapshot =
        WatchedSnapshot<Map<String, DBusValue>, DBusPropertiesChangedSignal>(
          read: () => remote.getAllProperties(interface),
          changes: dbusPropertiesChanged(remote, interface: interface),
          beforeRead: () => dbusSignalBarrier(object.client),
          requiresReload: (event) => event.invalidatedProperties.isNotEmpty,
          reduce:
              (properties, event) =>
                  Map.unmodifiable({...properties, ...event.changedProperties}),
          onData: (properties) => onChanged(Map.unmodifiable(properties)),
          onError: onError,
        );

    _snapshot = snapshot;
    _loading = snapshot.load().then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {
        if (!_disposed && identical(_snapshot, snapshot)) onError(error, stack);
      },
    );
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_service.close());
    unawaited(_snapshot?.close());
  }
}
