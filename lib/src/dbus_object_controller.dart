import 'dart:async';

import 'package:dbus/dbus.dart';
import 'package:logging/logging.dart';

import 'extensions.dart';
import 'logger.dart';

abstract class DbusObjectController<T> {
  final DBusClient client;
  final DBusObjectPath path;

  late final Logger log = createLogger('DbusObjCtrl@${path.shortenForDisplay()}');
  StreamSubscription? _sub;
  T? _current;
  T? get current => _current;
  void Function(T)? _onUpdate;

  DbusObjectController(this.client, this.path);

  // Required overrides

  /// Load full initial snapshot
  Future<T> loadInitial();

  /// Apply partial property updates (SYNC, PURE)
  /// NOTE: must return same instance if unchanged
  T applyChanges(T current, Map<String, DBusValue> changed);

  /// D-Bus interface this controller cares about
  String get interfaceName;

  // Public API

  Future<T> load() async {
    try {
      final initial = await loadInitial();
      _current = initial;
      _onUpdate?.call(initial);
      _startWatching();
      return initial;
    } catch (e, st) {
      log.severe('Failed to load $path', e, st);
      rethrow;
    }
  }

  void watch(void Function(T) onUpdate) {
    _onUpdate = onUpdate;
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }

  // Internals

  void _startWatching() {
    _sub?.cancel();

    _sub = DBusSignalStream(
      client,
      interface: 'org.freedesktop.DBus.Properties',
      name: 'PropertiesChanged',
      path: path,
      signature: DBusSignature('sa{sv}as'),
    ).listen((signal) {
      try {
        if (_sub == null) return;
        if (signal.values[0].asString() != interfaceName) return;
        if (_current == null) return;

        final old = _current!;
        final updated = applyChanges(
          _current!,
          signal.values[1].asStringVariantDict(),
        );

        if (identical(updated, _current)) return;

        emit(updated);
        onAfterUpdate(old, updated);
      } catch (e, st) {
        log.severe('Error processing PropertiesChanged signal', e, st);
      }
    });
  }

  void onAfterUpdate(T old, T updated) {}

  void emit(T updated) {
    try {
      _current = updated;
      _onUpdate?.call(updated);
    } catch (e, st) {
      log.severe('Error emitting update', e, st);
    }
  }
}
