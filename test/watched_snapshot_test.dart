import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jappeos_services/src/utils/dbus/watched_snapshot.dart';

void main() {
  test('subscribes first and retries a snapshot overlapping changes', () async {
    final events = StreamController<int>(sync: true);
    final reads = <Completer<int>>[];
    final values = <int>[];
    final watcher = WatchedSnapshot<int, int>(
      read: () {
        expect(events.hasListener, isTrue);
        final result = Completer<int>();
        reads.add(result);
        return result.future;
      },
      changes: events.stream,
      reduce: (_, value) => value,
      requiresReload: (_) => false,
      onData: values.add,
      onError: (error, stack) => fail('$error'),
    );
    final loaded = watcher.load();
    expect(identical(loaded, watcher.load()), isTrue);
    await Future<void>.delayed(Duration.zero);
    events.add(2);
    reads[0].complete(1);
    await Future<void>.delayed(Duration.zero);
    expect(values, isEmpty);
    expect(reads.length, 2);
    reads[1].complete(2);
    expect(await loaded, 2);
    events.add(3);
    expect(values, [2, 3]);
    await watcher.close();
    expect(events.hasListener, isFalse);
    await events.close();
  });

  test('invalidation refresh cannot overwrite a newer update', () async {
    final events = StreamController<int>(sync: true);
    final reads = <Completer<int>>[];
    final values = <int>[];
    final watcher = WatchedSnapshot<int, int>(
      read: () {
        final result = Completer<int>();
        reads.add(result);
        return result.future;
      },
      changes: events.stream,
      reduce: (_, event) => event,
      requiresReload: (event) => event == -1,
      onData: values.add,
      onError: (error, stack) => fail('$error'),
    );
    final loaded = watcher.load();
    await Future<void>.delayed(Duration.zero);
    reads[0].complete(1);
    await loaded;
    events.add(-1);
    await Future<void>.delayed(Duration.zero);
    events.add(3);
    reads[1].complete(2);
    await Future<void>.delayed(Duration.zero);
    reads[2].complete(3);
    await Future<void>.delayed(Duration.zero);
    expect(values, [1, 3]);
    await watcher.close();
    await events.close();
  });

  test('dispose suppresses pending read and future notifications', () async {
    final events = StreamController<int>(sync: true);
    final read = Completer<int>();
    final values = <int>[];
    final watcher = WatchedSnapshot<int, int>(
      read: () => read.future,
      changes: events.stream,
      reduce: (_, event) => event,
      requiresReload: (_) => false,
      onData: values.add,
      onError: (error, stack) => fail('$error'),
    );
    final loaded = watcher.load();
    final expectation = expectLater(loaded, throwsStateError);
    await Future<void>.delayed(Duration.zero);
    await watcher.close();
    read.complete(1);
    await expectation;
    events.add(2);
    expect(values, isEmpty);
    await expectLater(watcher.load(), throwsStateError);
    await watcher.close();
    await events.close();
  });

  test('a failed initial read can be retried', () async {
    final events = StreamController<int>(sync: true);
    var attempts = 0;
    final watcher = WatchedSnapshot<int, int>(
      read: () async {
        if (attempts++ == 0) throw StateError('temporary failure');
        return 42;
      },
      changes: events.stream,
      reduce: (_, event) => event,
      requiresReload: (_) => false,
      onData: (_) {},
      onError: (error, stack) => fail('$error'),
    );
    await expectLater(watcher.load(), throwsStateError);
    expect(await watcher.load(), 42);
    await watcher.close();
    await events.close();
  });
}
