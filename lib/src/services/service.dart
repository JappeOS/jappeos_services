import 'package:dbus/dbus.dart';
import 'package:flutter/widgets.dart';

const kSystemServiceName = 'org.jappeos.Core';
const kSessionServiceName = 'org.jappeos.Session';

abstract class Service extends ChangeNotifier {
  static DBusClient? _systemClient;
  static DBusClient? _sessionClient;
  static int _activeServiceCount = 0;

  static String getName(DBusClient client)
      => client == _systemClient! ? kSystemServiceName : kSessionServiceName;

  bool _mounted = false;
  late ServiceType _type;

  @protected
  DBusClient get client
      => _type == ServiceType.system ? _systemClient! : _sessionClient!;

  @protected
  bool get mounted => _mounted;

  Service(ServiceType type) {
    _type = type;

    if (_activeServiceCount == 0) {
      _systemClient = DBusClient.system();
      _sessionClient = DBusClient.session();
    }

    _activeServiceCount++;
    _mounted = true;
  }

  @mustCallSuper
  @override
  void dispose() {
    _mounted = false;
    _activeServiceCount--;
    if (_activeServiceCount == 0) {
      _systemClient?.close();
      _sessionClient?.close();
    }
    super.dispose();
  }
}

enum ServiceType {
  system,
  session,
}