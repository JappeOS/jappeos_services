import 'dart:async';

import 'package:dbus/dbus.dart';
import 'package:flutter/widgets.dart';

import '../utils/dbus/client_pool.dart';
import '../utils/dbus/resource.dart';

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

  final List<DbusResource> _resources = [];
  final Map<DbusResource, int> _generations = {};
  int _generation = 0;

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

  /// Changes whenever watched data is invalidated, including owner replacement.
  int get generation => _generation;

  ServiceStatus get status {
    if (!_mounted) return ServiceStatus.disposed;
    if (_resources.any((r) => r.status == ServiceStatus.failed)) {
      return ServiceStatus.failed;
    }
    if (_resources.any((r) => r.status == ServiceStatus.unavailable)) {
      return ServiceStatus.unavailable;
    }
    if (_resources.any((r) => r.status != ServiceStatus.ready)) {
      return ServiceStatus.loading;
    }
    return ServiceStatus.ready;
  }

  Object? get initializationError {
    for (final resource in _resources) {
      if (resource.error != null) return resource.error;
    }
    return null;
  }

  /// Services supply their watches; lifecycle mechanics are shared.
  @protected
  void initializeResources(List<DbusResource> resources) {
    assert(_resources.isEmpty);
    _resources.addAll(resources);

    for (final resource in resources) {
      _generations[resource] = resource.generation;
      resource.addListener(_resourceChanged);
    }

    scheduleMicrotask(() {
      if (_mounted) unawaited(init().catchError((Object _, StackTrace __) {}));
    });
  }

  void _resourceChanged() {
    for (final resource in _resources) {
      if (_generations[resource] != resource.generation) {
        _generations[resource] = resource.generation;
        _generation++;
      }
    }

    notifyListeners();
  }

  Future<void> init() async {
    if (!_mounted) throw StateError('Service is disposed');
    await Future.wait(
      _resources.map((resource) => resource.start()),
      eagerError: true,
    );
  }

  Future<void> retryInitialization() async {
    if (!_mounted) throw StateError('Service is disposed');
    await Future.wait(
      _resources.map((resource) => resource.retry()),
      eagerError: true,
    );
  }

  @override
  void notifyListeners() {
    if (_mounted) super.notifyListeners();
  }

  @mustCallSuper
  @override
  void dispose() {
    if (!_mounted) return;
    _mounted = false;

    for (final resource in _resources) {
      resource.removeListener(_resourceChanged);
    }

    if (_ownsClient) {
      DbusClientPool.release(
        _type == ServiceType.system ? DbusBus.system : DbusBus.session,
      );
    }

    super.dispose();
  }
}

enum ServiceType { system, session }
