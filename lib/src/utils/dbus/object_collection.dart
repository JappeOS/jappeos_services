import 'dart:async';

import 'package:dbus/dbus.dart';

import 'object_controller.dart';
import 'service_watcher.dart';
import 'signals.dart';
import 'watched_snapshot.dart';

/// Owns discovery, controllers, and model snapshots for a D-Bus collection.
/// Enumeration remains a callback because not all services use ObjectManager.
class DbusObjectCollection<T, C extends DbusObjectController<T>> {
  final DBusRemoteObject object;
  final String interface;
  final String addedSignal;
  final String removedSignal;
  final Future<List<DBusObjectPath>> Function(DBusRemoteObject) enumerate;
  final FutureOr<C> Function(DBusObjectPath, String owner) createController;
  final void Function() onChanged;
  final void Function(Object, StackTrace) onError;

  final _entries = <DBusObjectPath, _Entry<C>>{};
  final _values = <DBusObjectPath, T>{};
  late final DbusServiceWatcher _service = DbusServiceWatcher(
    client: object.client,
    destination: object.name,
    onChanged: _ownerChanged,
    onError: onError,
  );
  WatchedSnapshot<Set<DBusObjectPath>, (DBusObjectPath, bool)>? _snapshot;
  Future<void>? _loading;
  bool _disposed = false;

  DbusObjectCollection({
    required this.object,
    required this.interface,
    required this.addedSignal,
    required this.removedSignal,
    required this.enumerate,
    required this.createController,
    required this.onChanged,
    required this.onError,
  });

  List<T> get values => _values.values.toList(growable: false);
  T? operator [](DBusObjectPath path) => _values[path];
  C? controller(DBusObjectPath path) => _entries[path]?.controller;

  Future<void> start() async {
    if (_disposed) return;
    await _service.start(activate: true);
    await _loading;
  }

  void _ownerChanged(String? owner) {
    _reset();
    if (_disposed || owner == null) return;

    final remote = DBusRemoteObject(
      object.client,
      name: owner,
      path: object.path,
    );

    // Both membership signals must share one stream. Independent asynchronous
    // streams can deliver Added, Removed, Added out of wire order.
    final events = DBusSignalStream(
          object.client,
          sender: owner,
          path: object.path,
          interface: interface,
        )
        .where(
          (event) => event.name == addedSignal || event.name == removedSignal,
        )
        .map((event) {
          if (event.signature != DBusSignature('o')) {
            throw FormatException(
              'Invalid ${event.name} signature: ${event.signature}',
            );
          }
          return (event.values[0].asObjectPath(), event.name == addedSignal);
        });

    final snapshot =
        WatchedSnapshot<Set<DBusObjectPath>, (DBusObjectPath, bool)>(
          read: () async => (await enumerate(remote)).toSet(),
          changes: events,
          beforeRead: () => dbusSignalBarrier(object.client),
          requiresReload: (_) => false,
          reduce: (paths, event) {
            final updated = Set<DBusObjectPath>.of(paths);
            event.$2 ? updated.add(event.$1) : updated.remove(event.$1);
            return updated;
          },
          onData: (paths) => _reconcile(paths, owner),
          onError: onError,
        );

    _snapshot = snapshot;
    _loading = () async {
      try {
        await snapshot.load();
        await Future.wait(_entries.values.map((entry) => entry.loading));
      } catch (error, stack) {
        if (!_disposed && identical(_snapshot, snapshot)) {
          onError(error, stack);
        }
      }
    }();
  }

  void _reconcile(Set<DBusObjectPath> paths, String owner) {
    if (_disposed) return;

    for (final path in _entries.keys.toList()) {
      if (!paths.contains(path)) {
        _entries.remove(path)?.controller?.dispose();
        _values.remove(path);
      }
    }

    for (final path in paths) {
      if (_entries.containsKey(path)) continue;
      final entry = _Entry<C>();
      _entries[path] = entry;
      entry.loading = _load(path, owner, entry);
    }

    onChanged();
  }

  Future<void> _load(DBusObjectPath path, String owner, _Entry<C> entry) async {
    C? controller;
    try {
      controller = await createController(path, owner);
      if (_disposed || !identical(_entries[path], entry)) {
        controller.dispose();
        return;
      }

      entry.controller = controller;
      controller.watch((value) {
        if (_disposed || !identical(_entries[path], entry)) return;
        _values[path] = value;
        onChanged();
      });

      await controller.load();
    } catch (error, stack) {
      controller?.dispose();
      if (!_disposed && identical(_entries[path], entry)) {
        _entries.remove(path);
        _values.remove(path);
        onError(error, stack);
        onChanged();
      }
    }
  }

  void _reset() {
    unawaited(_snapshot?.close());
    _snapshot = null;
    for (final entry in _entries.values) {
      entry.controller?.dispose();
    }
    _entries.clear();
    _values.clear();
    if (!_disposed) onChanged();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_service.close());
    _reset();
  }
}

class _Entry<C> {
  C? controller;
  Future<void> loading = Future.value();
}
