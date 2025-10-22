import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'service_registry.dart';

class JappeosServiceProvider extends StatelessWidget {
  final Widget child;

  const JappeosServiceProvider({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: ServiceRegistry.create().map((svc) {
        return ChangeNotifierProvider(create: (_) => svc);
      }).toList(),
      child: child,
    );
  }
}