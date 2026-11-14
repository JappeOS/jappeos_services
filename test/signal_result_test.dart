import 'dart:async';
import 'dart:io';
import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jappeos_services/src/utils/dbus/signals.dart';

void main() {
  late DBusServer bus;
  late DBusClient client;
  late StreamController<int> signals;
  setUp(() async {
    bus = DBusServer();
    final address = await bus.listenAddress(
      DBusAddress.unix(dir: Directory.systemTemp),
    );
    client = DBusClient(address);
    signals = StreamController<int>();
  });
  tearDown(() async {
    await signals.close();
    await client.close();
    await bus.close();
  });
  test('method failure cancels result subscription without replay', () async {
    var calls = 0;
    final failure = StateError('Request failed');
    await expectLater(
      dbusCallWithSignalResult<int, int>(
        client: client,
        results: signals.stream,
        request: () async {
          calls++;
          throw failure;
        },
        matches: (id, result) => id == result,
        timeout: const Duration(seconds: 1),
      ),
      throwsA(same(failure)),
    );
    expect(calls, 1);
    expect(signals.hasListener, isFalse);
  });
  test('timeout cancels listener even while method reply is pending', () async {
    final reply = Completer<int>();
    var calls = 0;
    await expectLater(
      dbusCallWithSignalResult<int, int>(
        client: client,
        results: signals.stream,
        request: () {
          calls++;
          return reply.future;
        },
        matches: (id, result) => id == result,
        timeout: const Duration(milliseconds: 100),
      ),
      throwsA(isA<TimeoutException>()),
    );
    expect(calls, 1);
    expect(signals.hasListener, isFalse);
    reply.completeError(StateError('Late failure'));
    await Future<void>.delayed(Duration.zero);
  });
}
