import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../jappeos_services.dart';

sealed class ServiceRegistry {
  static List<SingleChildWidget> create() {
    return [
      ChangeNotifierProvider(create: (_) => LoggerService()),
      ChangeNotifierProvider(create: (_) => PowerManagerService()),
      ChangeNotifierProvider(create: (_) => SessionManagerService()),
      ChangeNotifierProvider(create: (_) => AccountManagerService()),
      ChangeNotifierProvider(create: (_) => NetworkManagerService()),
      ChangeNotifierProvider(create: (_) => AudioService()),
    ];
  }
}
