import 'dart:io';
import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jappeos_services/src/services/network_manager/dbus/device_proxy.dart';
import 'package:jappeos_services/src/services/network_manager/dbus/access_point_proxy.dart';
import 'package:jappeos_services/src/services/network_manager/dbus/wifi_device_proxy.dart';
import 'package:jappeos_services/src/services/network_manager/dbus/connection_proxy.dart';
import 'package:jappeos_services/src/services/network_manager/model/network_device.dart';
import 'package:jappeos_services/src/services/network_manager/service/network_device_controller.dart';
import 'package:jappeos_services/src/utils/dbus/signals.dart';

class PropertiesObject extends DBusObject {
  final Map<String, Map<String, DBusValue>> properties;
  PropertiesObject(super.path, this.properties);
  @override
  Future<DBusMethodResponse> getProperty(String interface, String name) async =>
      DBusGetPropertyResponse(properties[interface]![name]!);
  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall call) async {
    if (call.name == 'Connect') {
      await emitSignal(WifiDeviceProxy.interface, 'ConnectResult', [
        DBusUint64(41),
        DBusBoolean(false),
        DBusString(''),
        DBusString(''),
      ]);
      await emitSignal(WifiDeviceProxy.interface, 'ConnectResult', [
        DBusUint64(42),
        DBusBoolean(true),
        DBusString(''),
        DBusString(''),
      ]);
      return DBusMethodSuccessResponse([DBusUint64(42)]);
    }
    return DBusMethodSuccessResponse([]);
  }

  Future<void> update(String interface, Map<String, DBusValue> changed) async {
    properties[interface]!.addAll(changed);
    await emitPropertiesChanged(interface, changedProperties: changed);
  }
}

void main() {
  late DBusServer bus;
  late DBusClient server, client;
  late PropertiesObject device, connection, accessPoint;
  late WifiDeviceController controller;
  final path = DBusObjectPath('/test/device');
  final connectionPath = DBusObjectPath('/test/connection');
  final accessPointPath = DBusObjectPath('/test/ap');
  setUp(() async {
    bus = DBusServer();
    final address = await bus.listenAddress(
      DBusAddress.unix(dir: Directory.systemTemp),
    );
    server = DBusClient(address);
    client = DBusClient(address);
    device = PropertiesObject(path, {
      DeviceProxy.interface: {
        'Id': DBusString('wlan0'),
        'Type': DBusString('wifi'),
        'State': DBusString('connected'),
        'HwAddress': DBusString('00:11:22:33:44:55'),
        'Managed': DBusBoolean(true),
        'ActiveConnection': connectionPath,
      },
      WifiDeviceProxy.interface: {
        'AccessPoints': DBusArray.objectPath([accessPointPath]),
      },
    });
    connection = PropertiesObject(connectionPath, {
      ConnectionProxy.interface: {
        'Id': DBusString('saved-network'),
        'Type': DBusString('wifi'),
        'State': DBusString('activated'),
        'Ip4Address': DBusString('192.0.2.2'),
        'Ip6Address': DBusString(''),
        'SignalStrength': DBusInt32(80),
      },
    });
    accessPoint = PropertiesObject(accessPointPath, {
      AccessPointProxy.interface: {
        'Ssid': DBusString('saved-network'),
        'Strength': DBusInt32(80),
        'Security': DBusString('wpa-psk'),
        'Frequency': DBusInt32(2400),
        'Connected': DBusBoolean(true),
      },
    });
    await server.registerObject(accessPoint);
    await server.registerObject(device);
    await server.registerObject(connection);
    await server.requestName('org.jappeos.Test');
    controller = WifiDeviceController(
      client,
      path,
      serviceName: server.uniqueName,
    );
  });
  tearDown(() async {
    controller.dispose();
    await dbusSignalBarrier(client);
    await client.close();
    await server.close();
    await bus.close();
  });
  Future<void> until(bool Function() predicate) async {
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (!predicate()) {
      if (DateTime.now().isAfter(deadline)) {
        fail('Expected update not received');
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  test(
    'interface rename updates ID without losing device state or identity',
    () async {
      await controller.load();
      final originalPath = controller.current!.path;
      await device.update(DeviceProxy.interface, {'Id': DBusString('wlp3s0')});
      await until(() => controller.current!.id == 'wlp3s0');
      expect(controller.current!.path, originalPath);
      expect(controller.current!.isConnected, isTrue);
      await device.update(DeviceProxy.interface, {
        'State': DBusString('disconnected'),
      });
      await until(
        () => controller.current!.state == NetworkDeviceState.disconnected,
      );
      expect(controller.current!.id, 'wlp3s0');
    },
  );

  test('already connected device loads and continues to track state', () async {
    await controller.load();
    await until(() => controller.current?.activeConnection != null);
    expect(controller.current!.state, NetworkDeviceState.connected);
    await device.update(DeviceProxy.interface, {
      'State': DBusString('unavailable'),
      'ActiveConnection': DBusObjectPath.root,
    });
    await until(() => controller.current!.isUnavailable);
    await device.update(DeviceProxy.interface, {
      'State': DBusString('connected'),
      'ActiveConnection': connectionPath,
    });
    await until(
      () =>
          controller.current!.isConnected &&
          controller.current!.activeConnection != null,
    );
    await connection.update(ConnectionProxy.interface, {
      'SignalStrength': DBusInt32(90),
    });
    await until(
      () => controller.current!.activeConnection!.signalStrength == 90,
    );
    await accessPoint.update(AccessPointProxy.interface, {
      'Strength': DBusInt32(95),
    });
    await until(() => controller.current!.accessPoints.single.strength == 95);
    expect(controller.current!.isConnected, isTrue);
  });
  test(
    'unavailable device observes automatic connection after initialization',
    () async {
      device.properties[DeviceProxy.interface]!['State'] = DBusString(
        'unavailable',
      );
      device.properties[DeviceProxy.interface]!['ActiveConnection'] =
          DBusObjectPath.root;
      await controller.load();
      await device.update(DeviceProxy.interface, {
        'State': DBusString('connected'),
        'ActiveConnection': connectionPath,
      });
      await until(
        () =>
            controller.current!.isConnected &&
            controller.current!.activeConnection != null,
      );
    },
  );
  test(
    'controller handles result sent before method reply and skips unrelated IDs',
    () async {
      await controller.connect(ssid: 'saved-network');
    },
  );
  test('connect reply and result decode unsigned request IDs', () async {
    final proxy = WifiDeviceProxy(client, path, serviceName: server.uniqueName);
    final result = proxy.connectResult().firstWhere((event) => event.$1 == 42);
    await dbusSignalBarrier(client);
    expect(
      await proxy.connect(ssid: 'saved-network', security: '', secret: ''),
      42,
    );
    await device.emitSignal(WifiDeviceProxy.interface, 'ConnectResult', [
      DBusUint64(42),
      DBusBoolean(true),
      DBusString(''),
      DBusString(''),
    ]);
    expect((await result).$1, 42);
  });
}
