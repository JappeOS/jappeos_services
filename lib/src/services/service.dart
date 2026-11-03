import 'package:dbus/dbus.dart';
import 'package:flutter/widgets.dart';

import '../utils/dbus/client_pool.dart';

const kSystemServiceName = 'org.jappeos.Core';
const kSessionServiceName = 'org.jappeos.Session';

abstract class Service extends ChangeNotifier {
  /// Compatibility default for legacy JappeOS proxies. New proxies should
  /// specify their destination explicitly, independently of their bus.
  static String getName(DBusClient client) => switch (DbusClientPool.busOf(
    client,
  )) {
    DbusBus.system => kSystemServiceName,
    DbusBus.session => kSessionServiceName,
    null =>
      throw ArgumentError(
        'An explicit destination is required for this client',
      ),
  };

  bool _mounted = true;
  final ServiceType _type;
  final bool _ownsClient;

  @protected
  final DBusClient client;

  @protected
  bool get mounted => _mounted;

  /// A supplied client is borrowed; its caller remains responsible for closing it.
  Service(ServiceType type, {DBusClient? client})
    : _type = type,
      _ownsClient = client == null,
      client =
          client ??
          DbusClientPool.acquire(
            type == ServiceType.system ? DbusBus.system : DbusBus.session,
          );

  @override
  void notifyListeners() {
    if (_mounted) super.notifyListeners();
  }

  @mustCallSuper
  @override
  void dispose() {
    if (!_mounted) return;
    _mounted = false;
    if (_ownsClient) {
      DbusClientPool.release(
        _type == ServiceType.system ? DbusBus.system : DbusBus.session,
      );
    }
    super.dispose();
  }
}

enum ServiceType { system, session }
