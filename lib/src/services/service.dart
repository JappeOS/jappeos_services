import 'package:dbus/dbus.dart';
import 'package:flutter/widgets.dart';

abstract class Service extends ChangeNotifier {
  static DBusClient? _client;
  static int _activeServiceCount = 0;

  @protected
  DBusClient get client => _client!;

  Service() {
    if (_activeServiceCount == 0) _client = DBusClient.system();
    _activeServiceCount++;
  }

  @mustCallSuper
  @override
  void dispose() {
    _activeServiceCount--;
    if (_activeServiceCount == 0) _client?.close();
    super.dispose();
  }
}