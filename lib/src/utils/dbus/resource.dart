import 'dart:async';

import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';

import '../../logger.dart';
import 'service_watcher.dart';

/// Readiness of a service's watched data, not the state of a running operation.
enum ServiceStatus { loading, ready, unavailable, failed, disposed }

/// Shared activation, readiness deadline, retry and owner-generation handling.
/// Only discovery and reads run here. Mutating calls must never be replayed.
class DbusResource extends ChangeNotifier {
  // Temporary startup-race mitigation: one immediate attempt plus seven retries.
  // Each attempt retains its normal readiness timeout.
  static const _retryDelays = [50, 100, 200, 400, 800, 1600, 3200];
  static final _log = createLogger('DbusResource');

  final DBusClient client;
  final String destination;
  final Future<void> Function(String owner) load;
  final void Function() reset;
  final void Function(Object, StackTrace) onError;
  final Duration timeout;

  ServiceStatus _status = ServiceStatus.loading;
  Object? _error;
  int _generation = 0;
  DbusServiceWatcher? _watcher;
  Completer<void>? _ready;
  Timer? _deadline;
  Timer? _retryTimer;
  int _retryAttempt = 0;
  bool _disposed = false;
  int _watch = 0;

  DbusResource({
    required this.client,
    required this.destination,
    required this.load,
    required this.reset,
    required this.onError,
    this.timeout = const Duration(seconds: 30),
  });

  ServiceStatus get status => _status;
  Object? get error => _error;
  int get generation => _generation;

  Future<void> start() {
    if (_disposed) return Future.error(StateError('Resource is disposed'));
    if (_watcher == null) _connect();
    return _ready!.future;
  }

  Future<void> retry() {
    if (_disposed) return Future.error(StateError('Resource is disposed'));
    if (status == ServiceStatus.loading) return start();
    _connect();
    return _ready!.future;
  }

  void _ensurePending() {
    if (_ready == null || _ready!.isCompleted) {
      _ready = Completer<void>();

      // Owner changes can start loads without an explicit caller awaiting them.
      unawaited(
        _ready!.future.then<void>(
          (_) {},
          onError: (Object _, StackTrace __) {},
        ),
      );
    }
  }

  void _begin() {
    if (_ready == null || _ready!.isCompleted) _retryAttempt = 0;
    _ensurePending();
    _status = ServiceStatus.loading;
    _error = null;

    // Preserve the deadline across owner changes during one readiness wait.
    // A repeatedly restarting daemon must not keep callers waiting forever.
    if (_deadline?.isActive != true) {
      final pending = _ready;
      _deadline = Timer(timeout, () {
        if (!_disposed && identical(pending, _ready)) {
          fail(
            TimeoutException('Timed out waiting for $destination', timeout),
            StackTrace.current,
          );
        }
      });
    }

    notifyListeners();
  }

  void _connect() {
    final watch = ++_watch;
    unawaited(_watcher?.close());

    _generation++;
    _status = ServiceStatus.loading;
    _error = null;
    reset();
    _begin();

    final watcher = DbusServiceWatcher(
      client: client,
      destination: destination,
      onChanged: (owner) {
        if (_disposed || watch != _watch) return;
        _ownerChanged(owner);
      },
      onError: (error, stack) {
        if (!_disposed && watch == _watch && _watcher?.owner == null) {
          fail(error, stack);
        }
      },
    );

    _watcher = watcher;

    unawaited(
      watcher.start(activate: true).catchError((
        Object error,
        StackTrace stack,
      ) {
        if (!_disposed && watch == _watch && _watcher?.owner == null) {
          fail(error, stack);
        }
      }),
    );
  }

  void _ownerChanged(String? owner) {
    if (owner == null && status == ServiceStatus.failed) return;

    _generation++;
    _status = ServiceStatus.loading;
    _error = null;
    reset();
    _begin();

    if (owner == null) {
      _status = ServiceStatus.unavailable;
      notifyListeners();
      return;
    }

    final current = generation;
    unawaited(() async {
      try {
        await load(owner);
        if (_disposed || current != generation) return;
        _deadline?.cancel();
        _retryAttempt = 0;
        _status = ServiceStatus.ready;
        _error = null;
        if (!_ready!.isCompleted) _ready!.complete();
        notifyListeners();
      } catch (error, stack) {
        if (!_disposed && current == generation) fail(error, stack);
      }
    }());
  }

  void fail(Object failure, StackTrace stack) {
    if (_disposed || _retryTimer != null || status == ServiceStatus.failed) {
      return;
    }

    _generation++; // Invalidate the load, including a response after its deadline.
    _deadline?.cancel();
    reset();

    // Keep the same readiness future pending across initialization attempts.
    // Failures after readiness (ordinary refreshes) retain their existing policy.
    if (_ready != null &&
        !_ready!.isCompleted &&
        _retryAttempt < _retryDelays.length) {
      final delay = _retryDelays[_retryAttempt++];
      _status = ServiceStatus.loading;
      _error = null;
      ++_watch; // Ignore callbacks from the failed attempt during backoff.
      unawaited(_watcher?.close());

      _log.warning(
        'Initialization of $destination failed; retry $_retryAttempt/'
        '${_retryDelays.length} in $delay ms',
        failure,
        stack,
      );

      _retryTimer = Timer(Duration(milliseconds: delay), () {
        _retryTimer = null;
        if (!_disposed) _connect();
      });

      notifyListeners();
      return;
    }

    _status = ServiceStatus.failed;
    _error = failure;
    _ensurePending();
    _ready!.completeError(failure, stack);
    onError(failure, stack);

    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;

    _disposed = true;
    _retryTimer?.cancel();
    _retryTimer = null;
    _generation++;

    _deadline?.cancel();
    unawaited(_watcher?.close());
    reset();

    _status = ServiceStatus.disposed;
    if (_ready != null && !_ready!.isCompleted) {
      _ready!.completeError(StateError('Resource is disposed'));
    }

    super.dispose();
  }
}
