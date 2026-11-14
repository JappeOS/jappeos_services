import 'dart:async';

import 'package:dbus/dbus.dart';

Stream<DBusSignal> dbusSignals(
  DBusRemoteObject object,
  String interface,
  String name,
  DBusSignature signature,
) => DBusRemoteObjectSignalStream(
  object: object,
  interface: interface,
  name: name,
  signature: signature,
);

Stream<DBusPropertiesChangedSignal> dbusPropertiesChanged(
  DBusRemoteObject object, {
  String? interface,
}) => object.propertiesChanged.where(
  (signal) => interface == null || signal.propertiesInterface == interface,
);

/// Round trip on the same connection after installing signal listeners.
/// This orders the dbus package's queued AddMatch calls before snapshot reads.
Future<void> dbusSignalBarrier(DBusClient client) async {
  await client.callMethod(
    destination: 'org.freedesktop.DBus',
    path: DBusObjectPath('/org/freedesktop/DBus'),
    interface: 'org.freedesktop.DBus',
    name: 'GetId',
    replySignature: DBusSignature('s'),
  );
}

/// Subscribes before issuing a request whose completion arrives as a signal.
/// Buffers early results until the reply identifies the request. Never retries
/// the method call; timeout and errors always release the signal subscription.
Future<T> dbusCallWithSignalResult<K, T>({
  required DBusClient client,
  required Stream<T> results,
  required Future<K> Function() request,
  required bool Function(K, T) matches,
  required Duration timeout,
}) async {
  final completion = Completer<T>();
  final early = <T>[];
  K? key;
  var hasKey = false;
  var closed = false;

  void failed(Object error, StackTrace stack) {
    if (!closed && !completion.isCompleted) {
      completion.completeError(error, stack);
    }
  }

  void received(T value) {
    if (closed || completion.isCompleted) return;
    if (!hasKey) {
      early.add(value);
    } else if (matches(key as K, value)) {
      completion.complete(value);
    }
  }

  final subscription = results.listen(
    received,
    onError: failed,
    onDone:
        () => failed(StateError('Result stream closed'), StackTrace.current),
  );

  unawaited(() async {
    try {
      await dbusSignalBarrier(client);
      if (closed) return;
      key = await request();
      if (closed) return;
      hasKey = true;
      for (final value in early) {
        received(value);
      }
      early.clear();
    } catch (error, stack) {
      failed(error, stack);
    }
  }());
  
  try {
    return await completion.future.timeout(timeout);
  } finally {
    closed = true;
    early.clear();
    await subscription.cancel();
  }
}
