import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'service.dart';
import 'service_registry.dart';

class JappeosServiceProvider extends StatelessWidget {
  final Widget child;
  final List<Service Function()> services;

  const JappeosServiceProvider({
    required this.child,
    this.services = const [],
    super.key,
  });

  factory JappeosServiceProvider.all({
    required Widget child,
  }) {
    return JappeosServiceProvider(child: child);
  }

  factory JappeosServiceProvider.services({
    required List<Service Function()> services,
    required Widget child,
  }) {
    return JappeosServiceProvider(services: services, child: child);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: services.isEmpty
          ? ServiceRegistry.create()
          : ServiceRegistry.createWithServices(services),
      child: child,
    );
  }
}