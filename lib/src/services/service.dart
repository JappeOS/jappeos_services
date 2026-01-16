import 'package:dbus/dbus.dart';
import 'package:flutter/widgets.dart';

abstract class Service extends ChangeNotifier {
  static DBusClient? _client;
  static int _activeServiceCount = 0;

  bool _mounted = false;

  @protected
  DBusClient get client => _client!;

  @protected
  bool get mounted => _mounted;

  Service() {
    if (_activeServiceCount == 0) _client = DBusClient.system();
    _activeServiceCount++;
    _mounted = true;
  }

  @mustCallSuper
  @override
  void dispose() {
    _mounted = false;
    _activeServiceCount--;
    if (_activeServiceCount == 0) _client?.close();
    super.dispose();
  }
}