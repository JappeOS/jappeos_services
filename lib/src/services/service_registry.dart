import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../jappeos_services.dart';
import 'service.dart';

sealed class ServiceRegistry {
  static List<SingleChildWidget> create() {
    return [
      ChangeNotifierProvider(create: (_) => LoggerService()),
      ChangeNotifierProvider(create: (_) => PowerManagerService()),
      ChangeNotifierProvider(create: (_) => SessionManagerService()),
      ChangeNotifierProvider(create: (_) => AccountManagerService()),
      ChangeNotifierProvider(create: (_) => NetworkManagerService()),
      ChangeNotifierProvider(create: (_) => InstallerService()),
      ChangeNotifierProvider(create: (_) => AudioService()),
      ChangeNotifierProvider(create: (_) => NotificationManagerService()),
    ];
  }

  static List<SingleChildWidget> createWithServices(
    List<Service Function()> services,
  ) {
    final serviceProviders = services.map((serviceFactory) {
      final service = serviceFactory();
      return ChangeNotifierProvider(create: (_) => service);
    }).toList();

    return serviceProviders;
  }
}
