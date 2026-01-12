import 'package:dbus/dbus.dart';

import '../service.dart';

class NetworkManagerService extends Service {
  /// Returns a list of network device paths. Throws on failure.
  Future<List<DBusObjectPath>> listDevices() async {
    final response = await client.callMethod(
      path: DBusObjectPath('/org/jappeos/Core/NetworkManagerService'),
      destination: 'org.jappeos.Core',
      interface: "org.jappeos.Core.NetworkManagerService",
      name: "ListDevices",
    );

    final array = response.values[0].asArray();
    return array.map((e) => e.asObjectPath()).toList();
  }
}