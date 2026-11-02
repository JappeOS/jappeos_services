import 'dart:async';

import 'package:dbus/dbus.dart';

import 'signals.dart';

/// Tracks a destination's unique owner, including disappearance and replacement.
/// Does not reconnect a failed bus connection. Activation is opt-in.
class DbusServiceWatcher {
  final DBusClient client;
  final String destination;
  final void Function(String?) onChanged;
  final void Function(Object, StackTrace) onError;

  StreamSubscription<DBusNameOwnerChangedEvent>? _subscription;
  Future<void>? _starting;
  String? _owner;
  bool _known = false;
  bool _disposed = false;
  int _revision = 0;

  DbusServiceWatcher({
    required this.client,
    required this.destination,
    required this.onChanged,
    required this.onError,
  });

  String? get owner => _owner;

  Future<void> start({bool activate = false}) => _starting ??= _start(activate);

  Future<void> _start(bool activate) async {
    if (_disposed) return;

    _subscription = client.nameOwnerChanged.listen((event) {
      if (_disposed || event.name != destination) return;
      _revision++;
      _setOwner(event.newOwner);
    }, onError: onError);

    await dbusSignalBarrier(client);
    if (_disposed) return;

    final revision = _revision;
    final owner = await client.getNameOwner(destination);
    if (!_disposed && revision == _revision) _setOwner(owner);
    if (activate &&
        !_disposed &&
        _owner == null &&
        !destination.startsWith(':')) {
      try {
        await client.startServiceByName(destination);

        // Reconcile even if activation's owner-change callback is still queued.
        final revision = _revision;
        final owner = await client.getNameOwner(destination);
        if (!_disposed && revision == _revision) _setOwner(owner);
      } catch (error, stack) {
        if (!_disposed) onError(error, stack);
      }
    }
  }

  void _setOwner(String? owner) {
    if (_known && _owner == owner) return;
    _known = true;
    _owner = owner;
    onChanged(owner);
  }

  Future<void> close() async {
    if (_disposed) return;
    _disposed = true;
    await _subscription?.cancel();
    _subscription = null;
  }
}

/// Waits without leaking its owner subscription on timeout or failure.
Future<void> waitForDbusService(
  DBusClient client,
  String destination, {
  Duration timeout = const Duration(minutes: 1),
}) async {
  final ready = Completer<void>();
  final watcher = DbusServiceWatcher(
    client: client,
    destination: destination,
    onChanged: (owner) {
      if (owner != null && !ready.isCompleted) ready.complete();
    },
    onError: (error, stack) {
      if (!ready.isCompleted) ready.completeError(error, stack);
    },
  );
  try {
    await Future.wait<void>([
      watcher.start(),
      ready.future,
    ], eagerError: true).timeout(timeout);
  } finally {
    await watcher.close();
  }
}
