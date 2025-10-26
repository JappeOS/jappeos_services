import 'package:dbus/dbus.dart';

import '../service.dart';

class PowerManagerService extends Service {
  late final DBusClient _client;

  PowerManagerService() {
    _client = DBusClient.system();
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  /// Tries to shut down the system. Throws on failure.
  Future<void> shutdown() async {
    await _client.callMethod(
      path: DBusObjectPath('/org/jappeos/Core/PowerManagerService'),
      destination: 'org.jappeos.Core',
      interface: "org.jappeos.Core.PowerManagerService",
      name: "Shutdown",
    );
  }

  /// Tries to reboot the system. Throws on failure.
  Future<void> reboot() async {
    await _client.callMethod(
      path: DBusObjectPath('/org/jappeos/Core/PowerManagerService'),
      destination: 'org.jappeos.Core',
      interface: "org.jappeos.Core.PowerManagerService",
      name: "Reboot",
    );
  }

  /// Tries to suspend the system. Throws on failure.
  Future<void> suspend() async {
    await _client.callMethod(
      path: DBusObjectPath('/org/jappeos/Core/PowerManagerService'),
      destination: 'org.jappeos.Core',
      interface: "org.jappeos.Core.PowerManagerService",
      name: "Suspend",
    );
  }
}