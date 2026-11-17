import 'package:dbus/dbus.dart';

import '../../../dbus_proxy.dart';

class NotificationProxy extends DbusProxy {
  static const interface = 'org.jappeos.NotificationManager1.Notification';

  static const kAppName = 'AppName';
  static const kAppIcon = 'AppIcon';
  static const kSummary = 'Summary';
  static const kBody = 'Body';
  static const kActionKeys = 'ActionKeys';

  NotificationProxy(
    super.client,
    super.path, {
    super.serviceName = 'org.jappeos.NotificationManager1',
  });

  Future<String> getActionName(String actionKey) async {
    final reply = await object.callMethod(
      interface,
      'GetActionName',
      [DBusString(actionKey)],
    );
    return (reply.returnValues.first as DBusString).value;
  }

  Future<void> invokeAction(int action) async {
    await object.callMethod(
      interface,
      'InvokeAction',
      [object.path, DBusUint64(action)],
    );
  }

  Future<void> dismiss() async {
    await object.callMethod(
      interface,
      'DismissNotification',
      [object.path],
    );
  }

  Future<String> get appName async =>
      (await object.getProperty(interface, kAppName)).asString();

  Future<String> get appIcon async =>
      (await object.getProperty(interface, kAppIcon)).asString();

  Future<String> get summary async =>
      (await object.getProperty(interface, kSummary)).asString();

  Future<String> get body async =>
      (await object.getProperty(interface, kBody)).asString();

  Future<List<String>> get actionKeys async =>
      (await object.getProperty(interface, kActionKeys) as DBusArray)
        .children
        .cast<String>();
}
