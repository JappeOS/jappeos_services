import 'package:flutter_test/flutter_test.dart';
import 'package:jappeos_services/src/utils/dbus/client_pool.dart';

void main() {
  test('shares per-bus clients until the final lease is released', () async {
    // Constructing a client does not connect to the host bus.
    final first = DbusClientPool.acquire(DbusBus.system);
    final second = DbusClientPool.acquire(DbusBus.system);
    final session = DbusClientPool.acquire(DbusBus.session);
    expect(identical(first, second), isTrue);
    expect(identical(first, session), isFalse);
    expect(DbusClientPool.busOf(first), DbusBus.system);
    DbusClientPool.release(DbusBus.system);
    expect(DbusClientPool.busOf(second), DbusBus.system);
    DbusClientPool.release(DbusBus.system);
    expect(DbusClientPool.busOf(first), isNull);
    expect(DbusClientPool.busOf(session), DbusBus.session);
    final replacement = DbusClientPool.acquire(DbusBus.system);
    expect(identical(first, replacement), isFalse);
    DbusClientPool.release(DbusBus.system);
    DbusClientPool.release(DbusBus.session);
  });
}
