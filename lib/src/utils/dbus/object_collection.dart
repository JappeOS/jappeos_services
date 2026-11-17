import 'dart:async';

import 'package:dbus/dbus.dart';

import 'object_controller.dart';
import 'resource.dart';
import 'signals.dart';
import 'watched_snapshot.dart';

/// Owns discovery, controllers, and model snapshots for a D-Bus collection.
/// Enumeration remains a callback because not all services use ObjectManager.
class DbusObjectCollection<T, C extends DbusObjectController<T>> {
  final DBusRemoteObject object;
  final String interface;
  final String addedSignal;

  /// Optional signal carrying the path of an object whose data must be reloaded.
  final String? updatedSignal;

  final String removedSignal;
  final Future<List<DBusObjectPath>> Function(DBusRemoteObject) enumerate;
  final FutureOr<C> Function(DBusObjectPath, String owner) createController;
  final void Function() onChanged;
  final void Function(Object, StackTrace) onError;

  final _entries = <DBusObjectPath, _Entry<C>>{};
  final _values = <DBusObjectPath, T>{};
  late final DbusResource resource = DbusResource(
    client: object.client,
    destination: object.name,
    load: _loadOwner,
    reset: _reset,
    onError: onError,
    timeout: timeout,
  );
  final Duration timeout;
  WatchedSnapshot<Set<DBusObjectPath>, (DBusObjectPath, _CollectionChange)>?
  _snapshot;
  bool _disposed = false;

  DbusObjectCollection({
    required this.object,
    required this.interface,
    required this.addedSignal,
    this.updatedSignal,
    required this.removedSignal,
    required this.enumerate,
    required this.createController,
    required this.onChanged,
    required this.onError,
    this.timeout = const Duration(seconds: 30),
  });

  /// Loaded values in enumeration/addition order, regardless of load completion.
  /// Updates retain their position; entries still loading are omitted.
  List<T> get values => _entries.keys
      .where(_values.containsKey)
      .map((path) => _values[path] as T)
      .toList(growable: false);

  T? operator [](DBusObjectPath path) => _values[path];
  C? controller(DBusObjectPath path) => _entries[path]?.controller;

  Future<void> start() => resource.start();

  Future<void> _loadOwner(String owner) async {
    final remote = DBusRemoteObject(
      object.client,
      name: owner,
      path: object.path,
    );

    // All collection signals must share one stream. Independent asynchronous
    // streams can deliver Added, Removed, Added out of wire order.
    final events = DBusSignalStream(
          object.client,
          sender: owner,
          path: object.path,
          interface: interface,
        )
        .where(
          (event) =>
              event.name == addedSignal ||
              (updatedSignal != null && event.name == updatedSignal) ||
              event.name == removedSignal,
        )
        .map((event) {
          if (event.signature != DBusSignature('o')) {
            throw FormatException(
              'Invalid ${event.name} signature: ${event.signature}',
            );
          }
          final change =
              event.name == addedSignal
                  ? _CollectionChange.added
                  : event.name == removedSignal
                  ? _CollectionChange.removed
                  : _CollectionChange.updated;
          return (event.values[0].asObjectPath(), change);
        });

    final snapshot = WatchedSnapshot<
      Set<DBusObjectPath>,
      (DBusObjectPath, _CollectionChange)
    >(
      read: () async => (await enumerate(remote)).toSet(),
      changes: events,
      beforeRead: () => dbusSignalBarrier(object.client),
      requiresReload: (_) => false,
      reduce: (paths, event) {
        if (event.$2 == _CollectionChange.updated) {
          final entry = _entries[event.$1];
          if (entry != null) {
            entry.refreshRequested = true;
            entry.loading = _refresh(event.$1, entry);
          }
          return paths;
        }
        final updated = Set<DBusObjectPath>.of(paths);
        event.$2 == _CollectionChange.added
            ? updated.add(event.$1)
            : updated.remove(event.$1);
        return updated;
      },
      onData: (paths) => _reconcile(paths, owner),
      onError: resource.fail,
    );

    _snapshot = snapshot;
    await snapshot.load();
    await Future.wait(_entries.values.map((entry) => entry.loading));
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
        resource.fail(error, stack);
      }
    }
  }

  Future<void> _refresh(DBusObjectPath path, _Entry<C> entry) async {
    // Wait for creation or an earlier read before requesting fresh data.
    // Updates arriving during that wait can share the next read.
    await entry.loading;
    if (_disposed ||
        !identical(_entries[path], entry) ||
        !entry.refreshRequested) {
      return;
    }
    entry.refreshRequested = false;
    try {
      await entry.controller!.load();
    } catch (error, stack) {
      if (!_disposed && identical(_entries[path], entry)) {
        resource.fail(error, stack);
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
    resource.dispose();
  }
}

enum _CollectionChange { added, updated, removed }

class _Entry<C> {
  bool refreshRequested = false;
  C? controller;
  Future<void> loading = Future.value();
}
