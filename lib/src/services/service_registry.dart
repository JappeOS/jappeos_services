import '../../jappeos_services.dart';
import 'service.dart';

sealed class ServiceRegistry {
  static List<Service> create() {
    return [
      LoggerService(),
    ];
  }
}