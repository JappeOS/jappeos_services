import 'package:dbus/dbus.dart';

import '../service.dart';

class AccountManagerService extends Service {
  /// Creates the initial user with a password. Throws on failure.
  Future<void> createInitialUserWithPassword(String username, String realName, String password) async {
    await client.callMethod(
      path: DBusObjectPath('/org/jappeos/Core/AccountManagerService'),
      destination: 'org.jappeos.Core',
      interface: "org.jappeos.Core.AccountManagerService",
      name: "CreateInitialUserWithPassword",
      values: [
        DBusString(username),
        DBusString(realName),
        DBusString(password),
      ],
    );
  }

  /// Returns a list of object paths to users. Throws on failure.
  Future<List<String>> listUsers() async {
    final response = await client.callMethod(
      path: DBusObjectPath('/org/jappeos/Core/AccountManagerService'),
      destination: 'org.jappeos.Core',
      interface: "org.jappeos.Core.AccountManagerService",
      name: "ListUsers",
    );

    final array = response.values[0].asArray();
    return array.map((e) => e.asString()).toList();
  }

  /// Returns the value of a user property. Throws on failure.
  Future<DBusValue> getUserProperty(String userObject, String property) async {
    final response = await client.callMethod(
      path: DBusObjectPath('/org/jappeos/Core/AccountManagerService'),
      destination: 'org.jappeos.Core',
      interface: "org.jappeos.Core.AccountManagerService",
      name: "GetUserProperty",
      values: [
        DBusObjectPath(userObject),
        DBusString(property),
      ],
    );

    return response.values[0].asVariant();
  }
}