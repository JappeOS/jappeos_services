import 'package:dbus/dbus.dart';
import 'package:logging/logging.dart';

import '../../../logger.dart';
import '../../../utils/dbus/object_collection.dart';
import '../../service.dart';

import '../dbus/notification_manager_proxy.dart';
import '../model/notification.dart';
import 'notification_controller.dart';

class NotificationManagerService extends Service {
  final Logger log = createLogger('NotificationManagerService');
  late final NotificationManagerProxy _proxy;
  late final DbusObjectCollection<
    Notification,
    NotificationController
  >
  _collection;

  NotificationManagerService() : super(ServiceType.system) {
    _proxy = NotificationManagerProxy(client);
    _collection = DbusObjectCollection(
      object: _proxy.object,
      interface: NotificationManagerProxy.interface,
      addedSignal: 'NotificationAdded',
      updatedSignal: 'NotificationUpdated',
      removedSignal: 'NotificationRemoved',
      enumerate:
          (object) async =>
              (await object.callMethod(
                NotificationManagerProxy.interface,
                'GetNotifications',
                [],
                replySignature: DBusSignature('ao'),
              )).returnValues[0].asObjectPathArray().toList(),
      createController: _createController,
      onChanged: notifyListeners,
      onError:
          (error, stack) => log.severe('Notification watch failed', error, stack),
    );
    initializeResources([_collection.resource]);
  }

  List<Notification> get notifications => _collection.values;

  @override
  void dispose() {
    _collection.dispose();
    super.dispose();
  }

  // Service methods

  Future<String> getActionName(Notification notification, String key) async {
    final controller = _collection.controller(notification.path);
    return await controller!.getActionName(key);
  }

  Future<void> invokeAction(Notification notification, int keyIndex) async {
    final controller = _collection.controller(notification.path);
    await controller!.invokeAction(keyIndex);
  }

  Future<void> dismiss(Notification notification) async {
    final controller = _collection.controller(notification.path);
    await controller!.dismiss();
  }

  Future<void> clear() async {
    await _proxy.clearNotifications();
  }

  Future<NotificationController> _createController(
    DBusObjectPath path,
    String owner,
  ) async {
    return NotificationController(client, path, serviceName: owner);
  }
}
