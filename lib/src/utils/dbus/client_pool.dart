import 'dart:async';

import 'package:dbus/dbus.dart';

import '../../logger.dart';

enum DbusBus { system, session }

/// Reference-counted connections, opened only for the bus actually requested.
class DbusClientPool {
  static final _entries = <DbusBus, _ClientEntry>{};

  static DBusClient acquire(DbusBus bus) {
    final entry = _entries.putIfAbsent(
      bus,
      () => _ClientEntry(
        bus == DbusBus.system ? DBusClient.system() : DBusClient.session(),
      ),
    );
    entry.references++;
    return entry.client;
  }

  static DbusBus? busOf(DBusClient client) {
    for (final entry in _entries.entries) {
      if (identical(entry.value.client, client)) {
        return entry.key;
      }
    }
    return null;
  }

  static void release(DbusBus bus) {
    final entry = _entries[bus];
    if (entry == null) return;
    if (--entry.references != 0) return;
    _entries.remove(bus);
    unawaited(
      entry.client.close().catchError((Object error, StackTrace stack) {
        createLogger(
          'DbusClientPool',
        ).warning('Closing D-Bus connection failed', error, stack);
      }),
    );
  }
}

class _ClientEntry {
  final DBusClient client;
  int references = 0;
  _ClientEntry(this.client);
}
