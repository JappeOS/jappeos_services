import 'package:dbus/dbus.dart';

import '../../../utils/dbus/object_controller.dart';
import '../dbus/notification_proxy.dart';
import '../model/notification.dart';

class NotificationController
    extends DbusObjectController<Notification> {
  final NotificationProxy _proxy;

  NotificationController(
    super.client,
    super.path, {
    super.serviceName = 'org.jappeos.NotificationManager1',
  }) : _proxy = NotificationProxy(client, path, serviceName: serviceName);

  @override
  String get interfaceName => NotificationProxy.interface;

  @override
  Future<Notification> loadInitial() async {
    return Notification(
      path: path,
      appName: await _proxy.appName,
      appIcon: await _proxy.appIcon,
      summary: await _proxy.summary,
      body: await _proxy.body,
      actionKeys: await _proxy.actionKeys,
    );
  }

  @override
  Notification applyChanges(
    Notification current,
    Map<String, DBusValue> changed,
  ) {
    String? appName;
    String? appIcon;
    String? summary;
    String? body;
    List<String>? actionKeys;

    if (changed.containsKey(NotificationProxy.kAppName)) {
      appName = changed[NotificationProxy.kAppName]!.asString();
    }
    if (changed.containsKey(NotificationProxy.kAppIcon)) {
      appIcon = changed[NotificationProxy.kAppIcon]!.asString();
    }
    if (changed.containsKey(NotificationProxy.kSummary)) {
      summary = changed[NotificationProxy.kSummary]!.asString();
    }
    if (changed.containsKey(NotificationProxy.kBody)) {
      body = changed[NotificationProxy.kBody]!.asString();
    }
    if (changed.containsKey(NotificationProxy.kActionKeys)) {
      actionKeys = changed[NotificationProxy.kActionKeys]!
          .asArray()
          .map((v) => v.asString())
          .toList();
    }

    if (appName == null &&
        appIcon == null &&
        summary == null &&
        body == null &&
        actionKeys == null) {
      return current;
    }

    return current.copyWith(
      appName: appName,
      appIcon: appIcon,
      summary: summary,
      body: body,
      actionKeys: actionKeys,
    );
  }

  // Public methods

  Future<String> getActionName(String actionKey) async {
    return await _proxy.getActionName(actionKey);
  }

  Future<void> invokeAction(int keyIndex) async {
    final actionKeys = await _proxy.actionKeys;
    if (keyIndex < 0 || keyIndex >= actionKeys.length) {
      throw ArgumentError('Invalid action key index: $keyIndex');
    }
    await _proxy.invokeAction(keyIndex);
  }

  Future<void> dismiss() async {
    await _proxy.dismiss();
  }
}