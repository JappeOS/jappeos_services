import 'package:provider/provider.dart';

import '../../jappeos_services.dart';

sealed class ServiceRegistry {
  static List<ChangeNotifierProvider> create() {
    return [
      ChangeNotifierProvider(create: (_) => LoggerService()),
      ChangeNotifierProvider(create: (_) => PowerManagerService()),
      ChangeNotifierProvider(create: (_) => SessionManagerService()),
    ];
  }
}
