import 'dart:async';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jappeos_services/src/utils/dbus/object_collection.dart';
import 'package:jappeos_services/src/utils/dbus/object_controller.dart';
import 'package:jappeos_services/src/utils/dbus/property_watcher.dart';
import 'package:jappeos_services/src/utils/dbus/signals.dart';
import 'package:jappeos_services/src/utils/dbus/service_watcher.dart';
import 'package:jappeos_services/src/utils/dbus/resource.dart';

const destination = 'org.jappeos.Test';
const interface = 'org.jappeos.Test.Device';
final rootPath = DBusObjectPath('/org/jappeos/Test');
final devicePath = DBusObjectPath('/org/jappeos/Test/Device');

Future<void> until(bool Function() condition) async {
  final timeout = DateTime.now().add(const Duration(seconds: 3));
  while (!condition()) {
    if (DateTime.now().isAfter(timeout)) fail('Condition was not reached');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

class TestObject extends DBusObject {
  int value;
  List<DBusObjectPath> paths = [];
  Completer<void>? readGate;
  bool failRead = false;
  final readStarted = Completer<void>();
  TestObject(super.path, this.value);

  @override
  Future<DBusMethodResponse> getAllProperties(String requested) async {
    if (failRead) {
      return DBusMethodErrorResponse('org.freedesktop.DBus.Error.Failed', []);
    }
    final snapshot = value;
    if (!readStarted.isCompleted) readStarted.complete();
    await readGate?.future;
    return DBusGetAllPropertiesResponse({'Value': DBusInt32(snapshot)});
  }

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall call) async {
    if (call.name == 'List') {
      return DBusMethodSuccessResponse([DBusArray.objectPath(paths)]);
    }
    return DBusMethodErrorResponse.unknownMethod();
  }
}

class TestController extends DbusObjectController<int> {
  TestController(super.client, super.path, {required super.serviceName});
  @override
  String get interfaceName => interface;
  @override
  Future<int> loadInitial() async =>
      (await DBusRemoteObject(
        client,
        name: serviceName,
        path: path,
      ).getAllProperties(interface))['Value']!.asInt32();
  @override
  int applyChanges(int current, Map<String, DBusValue> changed) =>
      changed['Value']?.asInt32() ?? current;
}

void main() {
  late DBusServer bus;
  late DBusAddress address;
  late DBusClient service;
  late DBusClient client;
  late TestObject root;
  late TestObject device;
  final clients = <DBusClient>[];

  setUp(() async {
    bus = DBusServer();
    address = await bus.listenAddress(
      DBusAddress.unix(dir: Directory.systemTemp),
    );
    service = DBusClient(address);
    client = DBusClient(address);
    clients.addAll([service, client]);
    root = TestObject(rootPath, 1);
    device = TestObject(devicePath, 10);
    root.paths = [devicePath];
    await service.registerObject(root);
    await service.registerObject(device);
    await service.requestName(destination);
  });

  tearDown(() async {
    // Allow asynchronous subscription cancellation to finish before closing
    // the shared connection; no host system/session services are contacted.
    await dbusSignalBarrier(client);
    for (final connection in clients) {
      await connection.close();
    }
    clients.clear();
    await bus.close();
  });

  test(
    'properties filter sender/interface, reload invalidations and restart',
    () async {
      final values = <int>[];
      var unavailable = 0;
      final errors = <Object>[];
      final watcher = DbusPropertyWatcher(
        object: DBusRemoteObject(client, name: destination, path: devicePath),
        interface: interface,
        onChanged: (properties) => values.add(properties['Value']!.asInt32()),
        onUnavailable: () => unavailable++,
        onError: (error, stack) => errors.add(error),
      );
      addTearDown(watcher.dispose);
      await watcher.start();
      expect(values, [10]);
      final stranger = DBusClient(address);
      clients.add(stranger);
      final foreign = TestObject(devicePath, 100);
      await stranger.registerObject(foreign);
      await foreign.emitPropertiesChanged(
        interface,
        changedProperties: {'Value': DBusInt32(100)},
      );
      await device.emitPropertiesChanged(
        'org.jappeos.Unrelated',
        changedProperties: {'Value': DBusInt32(200)},
      );
      device.value = 11;
      await device.emitPropertiesChanged(
        interface,
        invalidatedProperties: ['Value'],
      );
      await until(() => values.contains(11));
      expect(values, [10, 11]);

      await service.releaseName(destination);
      await until(() => unavailable >= 2);
      final replacement = DBusClient(address);
      clients.add(replacement);
      await replacement.registerObject(TestObject(devicePath, 30));
      await replacement.requestName(destination);
      await until(() => values.contains(30));
      await device.emitPropertiesChanged(
        interface,
        changedProperties: {'Value': DBusInt32(99)},
      );
      await dbusSignalBarrier(client);
      expect(values, [10, 11, 30]);
      expect(errors, isEmpty);
    },
  );

  test(
    'old owner pending snapshot cannot overwrite replacement data',
    () async {
      device.readGate = Completer<void>();
      final values = <int>[];
      final watcher = DbusPropertyWatcher(
        object: DBusRemoteObject(client, name: destination, path: devicePath),
        interface: interface,
        onChanged: (properties) => values.add(properties['Value']!.asInt32()),
        onUnavailable: () {},
        onError: (error, stack) => fail('$error'),
      );
      addTearDown(watcher.dispose);
      final started = watcher.start();
      await device.readStarted.future;
      await service.releaseName(destination);
      final replacement = DBusClient(address);
      clients.add(replacement);
      await replacement.registerObject(TestObject(devicePath, 30));
      await replacement.requestName(destination);
      await until(() => values.contains(30));
      device.readGate!.complete();
      await started;
      expect(values, [30]);
    },
  );

  DbusObjectCollection<int, TestController> collection({
    required FutureOr<TestController> Function(DBusObjectPath, String) create,
    required void Function() changed,
  }) => DbusObjectCollection(
    object: DBusRemoteObject(client, name: destination, path: rootPath),
    interface: interface,
    addedSignal: 'Added',
    removedSignal: 'Removed',
    enumerate:
        (remote) async =>
            (await remote.callMethod(
              interface,
              'List',
              [],
              replySignature: DBusSignature('ao'),
            )).returnValues[0].asObjectPathArray().toList(),
    createController: create,
    onChanged: changed,
    onError: (error, stack) => fail('$error'),
  );

  test('removal during load does not resurrect an object', () async {
    device.readGate = Completer<void>();
    var changes = 0;
    final objects = collection(
      create: (path, owner) => TestController(client, path, serviceName: owner),
      changed: () => changes++,
    );
    addTearDown(objects.dispose);
    final started = objects.start();
    await device.readStarted.future;
    root.paths = [];
    await root.emitSignal(interface, 'Removed', [devicePath]);
    await until(() => objects.controller(devicePath) == null);
    device.readGate!.complete();
    await started;
    expect(objects.values, isEmpty);
    final previous = changes;
    objects.dispose();
    await root.emitSignal(interface, 'Added', [devicePath]);
    await dbusSignalBarrier(client);
    expect(changes, previous);
  });

  test(
    'duplicate additions share factory; removal cancels pending creation',
    () async {
      final created = Completer<TestController>();
      var factories = 0;
      final objects = collection(
        create: (path, owner) {
          factories++;
          return created.future;
        },
        changed: () {},
      );
      addTearDown(objects.dispose);
      final started = objects.start();
      await until(() => factories == 1);
      await root.emitSignal(interface, 'Added', [devicePath]);
      await root.emitSignal(interface, 'Added', [devicePath]);
      await root.emitSignal(interface, 'Removed', [devicePath]);
      await dbusSignalBarrier(client);
      // Wait for delivery on the other connection before resolving the factory.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final controller = TestController(
        client,
        devicePath,
        serviceName: service.uniqueName,
      );
      created.complete(controller);
      await started;
      expect(factories, 1);
      expect(controller.isDisposed, isTrue);
      expect(objects.values, isEmpty);
    },
  );

  test('collection is rediscovered when destination owner changes', () async {
    final objects = collection(
      create: (path, owner) => TestController(client, path, serviceName: owner),
      changed: () {},
    );
    addTearDown(objects.dispose);
    await objects.start();
    expect(objects.values, [10]);
    await service.releaseName(destination);
    await until(() => objects.values.isEmpty);
    final replacement = DBusClient(address);
    clients.add(replacement);
    final newRoot = TestObject(rootPath, 1)..paths = [devicePath];
    await replacement.registerObject(newRoot);
    await replacement.registerObject(TestObject(devicePath, 40));
    await replacement.requestName(destination);
    await until(() => objects.values.contains(40));
    expect(objects.values, [40]);
  });
  test('waiting for service times out cleanly and can wait again', () async {
    const name = 'org.jappeos.Late';
    await expectLater(
      waitForDbusService(
        client,
        name,
        timeout: const Duration(milliseconds: 20),
      ),
      throwsA(isA<TimeoutException>()),
    );
    final ready = waitForDbusService(client, name);
    await service.requestName(name);
    await ready;
    await service.releaseName(name);
  });

  test(
    'an initially unavailable destination recovers when it appears',
    () async {
      await service.releaseName(destination);
      final values = <int>[];
      final errors = <Object>[];
      final watcher = DbusPropertyWatcher(
        object: DBusRemoteObject(client, name: destination, path: devicePath),
        interface: interface,
        onChanged: (properties) => values.add(properties['Value']!.asInt32()),
        onUnavailable: () {},
        onError: (error, stack) => errors.add(error),
      );
      addTearDown(watcher.dispose);
      await expectLater(
        watcher.start(),
        throwsA(isA<DBusMethodResponseException>()),
      );
      expect(values, isEmpty);
      expect(
        errors,
        isNotEmpty,
      ); // No activation file on this private test bus.
      await service.requestName(destination);
      await until(() => values.contains(10));
    },
  );

  test(
    'slow initialization waits for the snapshot, including over three seconds',
    () async {
      device.readGate = Completer<void>();
      final values = <int>[];
      final watcher = DbusPropertyWatcher(
        object: DBusRemoteObject(client, name: destination, path: devicePath),
        interface: interface,
        onChanged: (properties) => values.add(properties['Value']!.asInt32()),
        onUnavailable: () {},
        onError: (error, stack) => fail('$error'),
      );
      addTearDown(watcher.dispose);
      var ready = false;
      final pending = watcher.start().then((_) => ready = true);
      await device.readStarted.future;
      await Future<void>.delayed(const Duration(milliseconds: 3100));
      expect(ready, false);
      expect(watcher.resource.status, ServiceStatus.loading);
      device.readGate!.complete();
      await pending;
      expect(watcher.resource.status, ServiceStatus.ready);
      expect(values, [10]);
    },
  );

  test(
    'timeout invalidates late data and explicit retry reloads the same owner',
    () async {
      device.readGate = Completer<void>();
      final values = <int>[];
      final watcher = DbusPropertyWatcher(
        object: DBusRemoteObject(client, name: destination, path: devicePath),
        interface: interface,
        timeout: const Duration(milliseconds: 100),
        onChanged: (properties) => values.add(properties['Value']!.asInt32()),
        onUnavailable: () {},
        onError: (error, stack) {},
      );
      addTearDown(watcher.dispose);
      await expectLater(watcher.start(), throwsA(isA<TimeoutException>()));
      expect(watcher.resource.status, ServiceStatus.failed);
      device.readGate!.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(values, isEmpty);
      device.readGate = null;
      device.value = 42;
      await watcher.resource.retry();
      expect(watcher.resource.status, ServiceStatus.ready);
      expect(values, [42]);
    },
  );

  test('collection child initialization failure rejects readiness', () async {
    final objects = DbusObjectCollection<int, TestController>(
      object: DBusRemoteObject(client, name: destination, path: rootPath),
      interface: interface,
      addedSignal: 'Added',
      removedSignal: 'Removed',
      enumerate: (remote) async => [devicePath],
      createController:
          (path, owner) => throw StateError('Cannot create device'),
      onChanged: () {},
      onError: (error, stack) {},
    );
    addTearDown(objects.dispose);
    await expectLater(objects.start(), throwsStateError);
    expect(objects.resource.status, ServiceStatus.failed);
    expect(objects.values, isEmpty);
  });

  test(
    'a refresh failure invalidates previously successful readiness',
    () async {
      final watcher = DbusPropertyWatcher(
        object: DBusRemoteObject(client, name: destination, path: devicePath),
        interface: interface,
        onChanged: (_) {},
        onUnavailable: () {},
        onError: (error, stack) {},
      );
      addTearDown(watcher.dispose);
      await watcher.start();
      device.failRead = true;
      await device.emitPropertiesChanged(
        interface,
        invalidatedProperties: ['Value'],
      );
      await until(() => watcher.resource.status == ServiceStatus.failed);
      await expectLater(
        watcher.start(),
        throwsA(isA<DBusMethodResponseException>()),
      );
      device.failRead = false;
      await watcher.resource.retry();
      expect(watcher.resource.status, ServiceStatus.ready);
    },
  );

  test(
    'disposal settles a pending readiness wait and ignores the reply',
    () async {
      device.readGate = Completer<void>();
      final values = <int>[];
      final watcher = DbusPropertyWatcher(
        object: DBusRemoteObject(client, name: destination, path: devicePath),
        interface: interface,
        onChanged: (properties) => values.add(properties['Value']!.asInt32()),
        onUnavailable: () {},
        onError: (error, stack) => fail('$error'),
      );
      final pending = expectLater(watcher.start(), throwsStateError);
      await device.readStarted.future;
      watcher.dispose();
      await pending;
      device.readGate!.complete();
      await dbusSignalBarrier(client);
      expect(values, isEmpty);
    },
  );

  test(
    'membership change during enumeration causes a fresh discovery',
    () async {
      final firstRead = Completer<List<DBusObjectPath>>();
      var reads = 0;
      final objects = DbusObjectCollection<int, TestController>(
        object: DBusRemoteObject(client, name: destination, path: rootPath),
        interface: interface,
        addedSignal: 'Added',
        removedSignal: 'Removed',
        enumerate: (remote) async {
          if (reads++ == 0) return firstRead.future;
          return [];
        },
        createController:
            (path, owner) => TestController(client, path, serviceName: owner),
        onChanged: () {},
        onError: (error, stack) => fail('$error'),
      );
      addTearDown(objects.dispose);
      final started = objects.start();
      await until(() => reads == 1);
      await root.emitSignal(interface, 'Removed', [devicePath]);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      firstRead.complete([devicePath]);
      await started;
      expect(reads, 2);
      expect(objects.values, isEmpty);
      expect(objects.controller(devicePath), isNull);
    },
  );
}
