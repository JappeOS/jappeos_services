import 'dart:async';

/// Subscribes before reading a snapshot, coalescing refreshes while a read runs.
/// A read overlapping an event is retried rather than publishing stale data.
/// The owner supplies protocol-specific reads and event reduction.
class WatchedSnapshot<T, E> {
  final Future<T> Function() read;
  final Stream<E> changes;
  final T Function(T, E) reduce;
  final bool Function(E) requiresReload;
  final void Function(T) onData;
  final void Function(Object, StackTrace) onError;
  final Future<void> Function()? beforeRead;

  StreamSubscription<E>? _subscription;
  Future<T>? _loading;
  T? _current;
  int _revision = 0;
  bool _disposed = false;

  WatchedSnapshot({
    required this.read,
    required this.changes,
    required this.reduce,
    required this.requiresReload,
    required this.onData,
    required this.onError,
    this.beforeRead,
  });

  Future<T> load() {
    if (_disposed) return Future.error(StateError('Snapshot is disposed'));
    _subscription ??= changes.listen(_changed, onError: onError);
    return _loading ??= _read();
  }

  Future<T> _read() async {
    try {
      await beforeRead?.call();
      while (true) {
        if (_disposed) throw StateError('Snapshot is disposed');

        final revision = _revision;
        final value = await read();
        if (_disposed) throw StateError('Snapshot is disposed');
        if (revision != _revision) continue;

        _current = value;
        onData(value);
        return value;
      }
    } finally {
      _loading = null;
    }
  }

  void _changed(E event) {
    if (_disposed) return;
    _revision++;
    if (_loading != null) return;
    
    try {
      if (_current == null || requiresReload(event)) {
        unawaited(load().then<void>((_) {}, onError: onError));
      } else {
        final updated = reduce(_current as T, event);
        if (!identical(updated, _current)) {
          _current = updated;
          onData(updated);
        }
      }
    } catch (error, stack) {
      onError(error, stack);
    }
  }

  /// Keeps the snapshot in sync with locally composed child-object state.
  void setCurrent(T value) => _current = value;

  Future<void> close() async {
    if (_disposed) return;
    _disposed = true;
    _revision++;
    await _subscription?.cancel();
    _subscription = null;
  }
}
