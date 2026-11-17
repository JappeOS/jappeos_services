import 'package:dbus/dbus.dart';

class Notification {
  final DBusObjectPath path;
  final String appName;
  final String appIcon;
  final String summary;
  final String body;
  final List<String> actionKeys;

  const Notification({
    required this.path,
    required this.appName,
    required this.appIcon,
    required this.summary,
    required this.body,
    required this.actionKeys,
  });

  Notification copyWith({
    DBusObjectPath? path,
    String? appName,
    String? appIcon,
    String? summary,
    String? body,
    List<String>? actionKeys,
  }) {
    return Notification(
      path: path ?? this.path,
      appName: appName ?? this.appName,
      appIcon: appIcon ?? this.appIcon,
      summary: summary ?? this.summary,
      body: body ?? this.body,
      actionKeys: actionKeys ?? this.actionKeys,
    );
  }
}