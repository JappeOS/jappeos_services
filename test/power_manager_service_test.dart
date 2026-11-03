import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jappeos_services/jappeos_services.dart';
import 'package:jappeos_services/src/services/power_manager/dbus/battery_device_proxy.dart';
import 'package:jappeos_services/src/services/power_manager/dbus/logind_proxy.dart';
import 'package:jappeos_services/src/services/power_manager/dbus/upower_proxy.dart';
import 'package:jappeos_services/src/services/power_manager/service/battery_device_controller.dart';
import 'package:jappeos_services/src/utils/dbus/signals.dart';

final batteryPath = DBusObjectPath(
  '/org/freedesktop/UPower/devices/battery_BAT0',
);
final mousePath = DBusObjectPath('/org/freedesktop/UPower/devices/mouse_test');

Future<void> until(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 3));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('Condition was not reached');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

Map<String, DBusValue> batteryProperties({double percentage = 73}) => {
  'Serial': DBusString('battery-serial'),
  'Type': DBusUint32(2),
  'PowerSupply': DBusBoolean(true),
  'IsPresent': DBusBoolean(true),
  'State': DBusUint32(2),
  'Percentage': DBusDouble(percentage),
  'TimeToEmpty': DBusInt64(7200),
  'TimeToFull': DBusInt64(0),
};

class PowerDevice extends DBusObject {
  final Map<String, DBusValue> properties;
  int reads = 0;
  PowerDevice(super.path, this.properties);

  @override
  Future<DBusMethodResponse> getAllProperties(String interface) async {
    expect(interface, BatteryDeviceProxy.interface);
    reads++;
    return DBusGetAllPropertiesResponse(properties);
  }

  Future<void> change(
    Map<String, DBusValue> changed, {
    bool invalidate = false,
  }) async {
    properties.addAll(changed);
    await emitPropertiesChanged(
      BatteryDeviceProxy.interface,
      changedProperties: invalidate ? {} : changed,
      invalidatedProperties: invalidate ? changed.keys.toList() : [],
    );
  }
}

class PowerRoot extends DBusObject {
  List<DBusObjectPath> devices;
  PowerRoot(this.devices) : super(DBusObjectPath('/org/freedesktop/UPower'));

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall call) async {
    expect(call.interface, UPowerProxy.interface);
    expect(call.name, 'EnumerateDevices');
    expect(call.values, isEmpty);
    return DBusMethodSuccessResponse([DBusArray.objectPath(devices)]);
  }
}

class LoginManager extends DBusObject {
  final calls = <DBusMethodCall>[];
  String capability = 'yes';
  String? failure;
  LoginManager() : super(DBusObjectPath('/org/freedesktop/login1'));

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall call) async {
    calls.add(call);
    expect(call.interface, LogindProxy.interface);
    if (failure != null) return DBusMethodErrorResponse(failure!);
    if (call.name.startsWith('Can')) {
      expect(call.values, isEmpty);
      expect(call.allowInteractiveAuthorization, isFalse);
      return DBusMethodSuccessResponse([DBusString(capability)]);
    }
    expect(call.values.length, 1);
    expect(call.values.single, isA<DBusBoolean>());
    return DBusMethodSuccessResponse([]);
  }
}

void main() {
  late DBusServer bus;
  late DBusAddress address;
  late DBusClient upower;
  late DBusClient login;
  late DBusClient client;
  late PowerRoot root;
  late PowerDevice battery;
  late PowerDevice display;
  late LoginManager manager;
  late PowerManagerService provider;
  final connections = <DBusClient>[];

  setUp(() async {
    bus = DBusServer();
    address = await bus.listenAddress(
      DBusAddress.unix(dir: Directory.systemTemp),
    );
    upower = DBusClient(address);
    login = DBusClient(address);
    client = DBusClient(address);
    connections.addAll([upower, login, client]);
    root = PowerRoot([batteryPath]);
    battery = PowerDevice(batteryPath, batteryProperties());
    display = PowerDevice(
      UPowerProxy.displayDevicePath,
      batteryProperties(percentage: 80),
    );
    await upower.registerObject(root);
    await upower.registerObject(battery);
    await upower.registerObject(display);
    await upower.requestName(UPowerProxy.destination);
    manager = LoginManager();
    await login.registerObject(manager);
    await login.requestName(LogindProxy.destination);
    provider = PowerManagerService(busClient: client);
    await provider.init();
  });

  tearDown(() async {
    provider.dispose();
    await dbusSignalBarrier(client);
    for (final connection in connections) {
      await connection.close();
    }
    connections.clear();
    await bus.close();
  });

  test(
    'reads UPower directly, keeping physical and display devices separate',
    () {
      expect(provider.devices, hasLength(1));
      final device = provider.devices.single;
      expect(device.id, 'battery-serial');
      expect(device.type, BatteryDeviceType.battery);
      expect(device.state, BatteryDeviceState.discharging);
      expect(device.isPowerSupply, isTrue);
      expect(device.isPresent, isTrue);
      expect(device.chargePercentage, 73);
      expect(device.timeToEmpty, const Duration(hours: 2));
      expect(device.timeToFull, Duration.zero);
      expect(provider.displayDevice?.chargePercentage, 80);
      expect(
        battery.reads,
        1,
      ); // A single GetAll snapshot, not separate Get calls.
      expect(manager.calls, isEmpty);
    },
  );

  test(
    'updates properties, reloads invalidations, and handles device hotplug',
    () async {
      await battery.change({
        'Percentage': DBusDouble(50),
        'State': DBusUint32(1),
      });
      await until(() => provider.devices.single.chargePercentage == 50);
      expect(provider.devices.single.state, BatteryDeviceState.charging);
      expect(provider.devices.single.id, 'battery-serial');
      await battery.change({'TimeToFull': DBusInt64(900)}, invalidate: true);
      await until(() => provider.devices.single.timeToFull.inMinutes == 15);
      await display.change({'IsPresent': DBusBoolean(false)});
      await until(() => provider.displayDevice == null);
      await display.change({
        'IsPresent': DBusBoolean(true),
        'Percentage': DBusDouble(90),
      });
      await until(() => provider.displayDevice?.chargePercentage == 90);

      final mouse = PowerDevice(mousePath, {
        'Type': DBusUint32(5),
        'Percentage': DBusDouble(45),
      });
      await upower.registerObject(mouse);
      root.devices.add(mousePath);
      await root.emitSignal(UPowerProxy.interface, 'DeviceAdded', [mousePath]);
      await until(() => provider.devices.length == 2);
      final model = provider.devices.firstWhere(
        (device) => device.type == BatteryDeviceType.mouse,
      );
      expect(model.isPowerSupply, isFalse);
      expect(model.id, '');
      expect(model.state, BatteryDeviceState.unknown);
      root.devices.remove(mousePath);
      await root.emitSignal(UPowerProxy.interface, 'DeviceRemoved', [
        mousePath,
      ]);
      await until(() => provider.devices.length == 1);
    },
  );

  test(
    'uses logind methods, boolean arguments, and explicit interactive authorization',
    () async {
      await provider.shutdown();
      await provider.reboot();
      await provider.suspend();
      await provider.hibernate();
      expect(manager.calls.map((call) => call.name), [
        'PowerOff',
        'Reboot',
        'Suspend',
        'Hibernate',
      ]);
      for (final call in manager.calls) {
        expect(call.values, [DBusBoolean(false)]);
        expect(call.allowInteractiveAuthorization, isFalse);
      }
      manager.calls.clear();
      await provider.shutdown(interactive: true);
      await provider.reboot(interactive: true);
      await provider.suspend(interactive: true);
      await provider.hibernate(interactive: true);
      for (final call in manager.calls) {
        expect(call.values, [DBusBoolean(true)]);
        expect(call.allowInteractiveAuthorization, isTrue);
      }
    },
  );

  test(
    'capability results preserve authorization/support distinctions and are fresh',
    () async {
      for (final entry
          in {
            'yes': PowerActionCapability.allowed,
            'challenge': PowerActionCapability.authenticationRequired,
            'no': PowerActionCapability.denied,
            'na': PowerActionCapability.unsupported,
            'future-value': PowerActionCapability.unknown,
          }.entries) {
        manager.capability = entry.key;
        expect(await provider.canShutdown(), entry.value);
        expect(await provider.canReboot(), entry.value);
        expect(await provider.canSuspend(), entry.value);
        expect(await provider.canHibernate(), entry.value);
      }
      expect(manager.calls.take(4).map((call) => call.name), [
        'CanPowerOff',
        'CanReboot',
        'CanSuspend',
        'CanHibernate',
      ]);
    },
  );

  test('logind errors propagate without fallback or retry', () async {
    for (final error in [
      'org.freedesktop.DBus.Error.AccessDenied',
      'org.freedesktop.login1.OperationInProgress',
    ]) {
      manager.failure = error;
      await expectLater(
        provider.hibernate(),
        throwsA(isA<DBusMethodResponseException>()),
      );
      expect(manager.calls.last.name, 'Hibernate');
    }
    expect(manager.calls, hasLength(2));
    await expectLater(
      provider.canHibernate(),
      throwsA(isA<DBusMethodResponseException>()),
    );
  });

  test(
    'UPower restart refreshes models while power actions remain independent',
    () async {
      await upower.releaseName(UPowerProxy.destination);
      await until(
        () => provider.devices.isEmpty && provider.displayDevice == null,
      );
      await provider.hibernate();
      expect(manager.calls.single.name, 'Hibernate');
      final replacement = DBusClient(address);
      connections.add(replacement);
      await replacement.registerObject(PowerRoot([batteryPath]));
      await replacement.registerObject(
        PowerDevice(batteryPath, batteryProperties(percentage: 20)),
      );
      await replacement.registerObject(
        PowerDevice(
          UPowerProxy.displayDevicePath,
          batteryProperties(percentage: 25),
        ),
      );
      await replacement.requestName(UPowerProxy.destination);
      await until(
        () =>
            provider.devices.isNotEmpty &&
            provider.displayDevice?.chargePercentage == 25,
      );
      expect(provider.devices.single.chargePercentage, 20);
      await battery.change({'Percentage': DBusDouble(99)});
      await dbusSignalBarrier(client);
      expect(provider.devices.single.chargePercentage, 20);
    },
  );

  test('logind restart routes actions to its replacement', () async {
    await login.releaseName(LogindProxy.destination);
    final replacement = DBusClient(address);
    connections.add(replacement);
    final next = LoginManager()..capability = 'na';
    await replacement.registerObject(next);
    await replacement.requestName(LogindProxy.destination);
    expect(await provider.canHibernate(), PowerActionCapability.unsupported);
    await provider.suspend();
    expect(next.calls.map((call) => call.name), ['CanHibernate', 'Suspend']);
    expect(manager.calls, isEmpty);
    expect(provider.devices.single.chargePercentage, 73);
  });

  test(
    'disposal keeps a borrowed connection alive and stops notifications',
    () async {
      var notifications = 0;
      provider.addListener(() => notifications++);
      provider.dispose();
      await battery.change({'Percentage': DBusDouble(10)});
      await dbusSignalBarrier(client);
      expect(notifications, 0);
      expect(
        await client.getNameOwner(LogindProxy.destination),
        login.uniqueName,
      );
    },
  );

  test('future UPower enum values are unknown without losing other fields', () {
    final properties =
        batteryProperties()
          ..['Type'] = DBusUint32(999)
          ..['State'] = DBusUint32(999);
    final model = BatteryDeviceController.fromProperties(properties);
    expect(model.type, BatteryDeviceType.unknown);
    expect(model.state, BatteryDeviceState.unknown);
    expect(model.chargePercentage, 73);
    expect(
      BatteryDeviceController.fromProperties({}).timeToEmpty,
      Duration.zero,
    );
  });
}
