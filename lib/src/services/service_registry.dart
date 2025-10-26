import 'package:jappeos_services/src/services/power_manager/power_manager_service.dart';
import 'package:jappeos_services/src/services/session_manager/session_manager_service.dart';

import '../../jappeos_services.dart';
import 'service.dart';

sealed class ServiceRegistry {
  static List<Service> create() {
    return [
      LoggerService(),
      PowerManagerService(),
      SessionManagerService(),
    ];
  }
}