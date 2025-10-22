import 'package:dbus/dbus.dart';

import '../service.dart';

// TODO: Add documentation
class LoggerService extends Service {
  void emerg(String message) => _sendLogMessage("emerg", message);
  void alert(String message) => _sendLogMessage("alert", message);
  void crit(String message) => _sendLogMessage("crit", message);
  void err(String message) => _sendLogMessage("err", message);
  void warn(String message) => _sendLogMessage("warn", message);
  void notice(String message) => _sendLogMessage("notice", message);
  void info(String message) => _sendLogMessage("info", message);
  void debug(String message) => _sendLogMessage("debug", message);

  // TODO: Remove excess printing
  Future<void> _sendLogMessage(String level, String message) async {
    final client = DBusClient.system();

    try {
      final response = await client.callMethod(
        path: DBusObjectPath('/org/jappeos/Core/LoggerService'),
        destination: 'org.jappeos.Core',
        interface: "org.jappeos.Core.LoggerService",
        name: "Log",
        values: [
          DBusString(level),
          DBusString(message),
        ],
      );

      print('Method call succeeded: $response');
    } catch (e) {
      print('D-Bus call failed: $e');
    } finally {
      await client.close();
    }
  }
}