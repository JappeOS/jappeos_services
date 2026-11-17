import 'package:dbus/dbus.dart';

import '../../../dbus_proxy.dart';

class NotificationManagerProxy extends DbusProxy {
  static const interface = 'org.jappeos.NotificationManager1';

  NotificationManagerProxy(
    DBusClient client, {
    String serviceName = 'org.jappeos.NotificationManager1',
  }) : super(
         client,
         DBusObjectPath('/org/jappeos/NotificationManager1'),
         serviceName: serviceName,
       );

  Future<List<DBusObjectPath>> getNotifications() async {
    final reply = await object.callMethod(interface, 'GetNotifications', const []);
    return (reply.returnValues.first as DBusArray).children
        .cast<DBusObjectPath>();
  }

  Future<void> clearNotifications() async {
    await object.callMethod(interface, 'ClearNotifications', const []);
  }

  Stream<DBusObjectPath> notificationAdded() =>
      objectPathSignals(interface, 'NotificationAdded');

  Stream<DBusObjectPath> notificationUpdated() =>
      objectPathSignals(interface, 'NotificationUpdated');

  Stream<DBusObjectPath> notificationRemoved() =>
      objectPathSignals(interface, 'NotificationRemoved');
}
