import 'package:logging/logging.dart';

bool _isInitialized = false;

Logger createLogger(String name) {
  if (!_isInitialized) {
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      // ignore: avoid_print
      print(
          '${record.time} | ${record.level.name.toUpperCase()} | ${record.loggerName}: ${record.message}');
      if (record.error != null) {
        // ignore: avoid_print
        print('Error: ${record.error}');
      }
      if (record.stackTrace != null) {
        // ignore: avoid_print
        print('StackTrace: ${record.stackTrace}');
      }
    });
    _isInitialized = true;
  }
  return Logger(name);
}