import 'package:dbus/dbus.dart';

import '../../../dbus_proxy.dart';
import '../model/power_action_capability.dart';

class LogindProxy extends DbusProxy {
  static const destination = 'org.freedesktop.login1';
  static const interface = 'org.freedesktop.login1.Manager';

  LogindProxy(DBusClient client)
    : super(
        client,
        DBusObjectPath('/org/freedesktop/login1'),
        serviceName: destination,
      );

  Future<void> shutdown({bool interactive = false}) =>
      _action('PowerOff', interactive);
  Future<void> reboot({bool interactive = false}) =>
      _action('Reboot', interactive);
  Future<void> suspend({bool interactive = false}) =>
      _action('Suspend', interactive);
  Future<void> hibernate({bool interactive = false}) =>
      _action('Hibernate', interactive);

  Future<PowerActionCapability> canShutdown() => _capability('CanPowerOff');
  Future<PowerActionCapability> canReboot() => _capability('CanReboot');
  Future<PowerActionCapability> canSuspend() => _capability('CanSuspend');
  Future<PowerActionCapability> canHibernate() => _capability('CanHibernate');

  Future<void> _action(String method, bool interactive) async {
    await object.callMethod(
      interface,
      method,
      [DBusBoolean(interactive)],
      replySignature: DBusSignature(''),
      allowInteractiveAuthorization: interactive,
    );
  }

  Future<PowerActionCapability> _capability(String method) async {
    final result = await object.callMethod(
      interface,
      method,
      [],
      replySignature: DBusSignature('s'),
    );
    return PowerActionCapability.fromLogind(
      result.returnValues.single.asString(),
    );
  }
}
