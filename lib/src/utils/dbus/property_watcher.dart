import 'dart:async';

import 'package:dbus/dbus.dart';

import 'resource.dart';
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

  late final DbusResource resource = DbusResource(
    client: object.client,
    destination: object.name,
    load: _loadOwner,
    reset: _reset,
    onError: onError,
    timeout: timeout,
  );
  final Duration timeout;
  WatchedSnapshot<Map<String, DBusValue>, DBusPropertiesChangedSignal>?
  _snapshot;
  bool _disposed = false;

  DbusPropertyWatcher({
    required this.object,
    required this.interface,
    required this.onChanged,
    required this.onUnavailable,
    required this.onError,
    this.timeout = const Duration(seconds: 30),
  });

  Future<void> start() => resource.start();

  void _reset() {
    unawaited(_snapshot?.close());
    _snapshot = null;
    if (!_disposed) onUnavailable();
  }

  Future<void> _loadOwner(String owner) async {
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
          onError: resource.fail,
        );

    _snapshot = snapshot;
    await snapshot.load();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    resource.dispose();
  }
}
