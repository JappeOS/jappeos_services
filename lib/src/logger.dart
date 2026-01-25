import 'package:logging/logging.dart';

bool _isInitialized = false;
const String packageName = 'jappeos_services';

Logger createLogger(String name) {
  if (!_isInitialized) {
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      // ignore: avoid_print
      print(
          '${record.time} | ${record.level.name.toUpperCase()} | $packageName | ${record.loggerName}: ${record.message}');
      if (record.error != null) {
        // ignore: avoid_print
        print('\tError: ${record.error}');
      }
      if (record.stackTrace != null) {
        // ignore: avoid_print
        print('\t${record.stackTrace.toString().replaceAll("\n", "\n\t")}');
      }
    });
    _isInitialized = true;
  }
  return Logger(name);
}