import 'package:dbus/dbus.dart';

import '../service.dart';

class SessionManagerService extends Service {
  /// Tries to create a session with the specified parameters. Throws on failure.
  Future<SessionCreatedInfo> createSession(String username, String password) async {
    final response = await client.callMethod(
      path: DBusObjectPath('/org/jappeos/Core/SessionManagerService'),
      destination: 'org.jappeos.Core',
      interface: "org.jappeos.Core.SessionManagerService",
      name: "CreateSession",
      values: [
        DBusString(username),
        DBusString(password),
      ],
    );

    return SessionCreatedInfo(
      sessionId: response.values[0].asString(),
      uid: response.values[1].asUint32(),
      seat: response.values[2].asString(),
    );
  }

  /// Tries to stop a session with the specified ID. Throws on failure.
  Future<void> stopSession(String sessionId) async {
    await client.callMethod(
      path: DBusObjectPath('/org/jappeos/Core/SessionManagerService'),
      destination: 'org.jappeos.Core',
      interface: "org.jappeos.Core.SessionManagerService",
      name: "StopSession",
      values: [
        DBusString(sessionId),
      ],
    );
  }

  /// Returns a list of all currently running sessions on the system. Throws on failure and skips invalid items.
  Future<List<SessionInfo>> listSessions(String message) async {
    final response = await client.callMethod(
      path: DBusObjectPath('/org/jappeos/Core/SessionManagerService'),
      destination: 'org.jappeos.Core',
      interface: "org.jappeos.Core.SessionManagerService",
      name: "ListSessions",
    );

    final array = response.values[0].asArray();
    List<SessionInfo> list = [];
    for (var it in array) {
      final struct = it.asStruct();
      try {
        list.add(SessionInfo(
          sessionId: struct[0].asString(),
          username: struct[1].asString(),
          uid: struct[2].asUint32(),
          seat: struct[3].asString(),
          scope: struct[4].asString(),
        ));
      } on Exception {
        continue;
      }
    }

    return list;
  }
}

class SessionCreatedInfo {
  final String sessionId;
  final int uid;
  final String seat;

  SessionCreatedInfo({required this.sessionId, required this.uid, required this.seat});
}

class SessionInfo {
  final String sessionId;
  final String username;
  final int uid;
  final String seat;
  final String scope;

  SessionInfo({required this.sessionId, required this.username, required this.uid, required this.seat, required this.scope});
}