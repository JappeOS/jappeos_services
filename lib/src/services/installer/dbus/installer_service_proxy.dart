import 'package:dbus/dbus.dart';

import '../../../dbus_proxy.dart';

class InstallerServiceProxy extends DbusProxy {
  static const interface =
      'org.jappeos.Core.InstallerService';

  static const kState = 'State';
  static const kErrorMessage = 'ErrorMessage';
  static const kProgress = 'Progress';
  static const kCurrentLocale = 'CurrentLocale';
  static const kCurrentTimezone = 'CurrentTimezone';
  static const kCurrentKeyboardLayout = 'CurrentKeyboardLayout';

  InstallerServiceProxy(DBusClient client)
      : super(
          client,
          DBusObjectPath('/org/jappeos/Core/InstallerService'),
        );

  Future<(
    Map<String, String>,
    List<String>,
    Map<String, (String, Map<String, String>)>)> getLocaleInfo() async {
    final reply = await object.callMethod(
      interface,
      'GetLocaleInfo',
      [],
    );

    return (
      (reply.returnValues[0] as DBusDict).children
          .cast<DBusString, DBusString>()
          .map((k, v) => MapEntry(k.value, v.value)),
      (reply.returnValues[1] as DBusArray)
          .children
          .cast<DBusString>()
          .map((s) => s.value)
          .toList(),
      (reply.returnValues[2] as DBusDict).children
          .cast<DBusString, DBusStruct>()
          .map((k, v) => MapEntry(
                k.value,
                (
                  (v.children[0] as DBusString).value,
                  (v.children[1] as DBusDict).children
                      .cast<DBusString, DBusString>()
                      .map((kk, vv) => MapEntry(kk.value, vv.value)),
                ),
              )),
    );
  }

  Future<Map<String,
             (int, List<(String, String, int, String)>)>> getStorageInfo() async {
    final reply = await object.callMethod(
      interface,
      'GetStorageInfo',
      [],
    );

    return (reply.returnValues[0] as DBusDict).children
        .cast<DBusString, DBusStruct>()
        .map((k, v) => MapEntry(
              k.value,
              (
                (v.children[0] as DBusUint64).value,
                (v.children[1] as DBusArray)
                    .children
                    .cast<DBusStruct>()
                    .map((s) {
                      final children = s.children;
                      return (
                        (children[0] as DBusString).value,
                        (children[1] as DBusString).value,
                        (children[2] as DBusUint64).value,
                        (children[3] as DBusString).value,
                      );
                    })
                    .toList(),
              ),
            ));
  }

  Future<(int, List<String>)> createInstallPlan(
    String hostname,
    String username,
    String password,
    String timezone,
    String locale,
    (String, String) keyboardLayout,
    (String, int, List<(String, String)>, List<(int, Map<String, DBusVariant>)>) disk,
    bool installProprietary,
    bool installRecommendedDrivers) async {
    final reply = await object.callMethod(
      interface,
      'CreateInstallPlan',
      [
        DBusString(hostname),
        DBusString(username),
        DBusString(password),
        DBusString(timezone),
        DBusString(locale),
        DBusStruct([
          DBusString(keyboardLayout.$1),
          DBusString(keyboardLayout.$2),
        ]),
        DBusStruct([
          DBusString(disk.$1),
          DBusUint64(disk.$2),
          DBusArray(
            DBusSignature('(ss)'),
            disk.$3.map((v) => DBusStruct([
              DBusString(v.$1),
              DBusString(v.$2),
            ])).toList(),
          ),
          DBusArray(
            DBusSignature('(t{sv})'),
            disk.$4.map((v) => DBusStruct([
              DBusUint64(v.$1),
              DBusDict(
                DBusSignature('s'),
                DBusSignature('v'),
                v.$2.map((kk, vv) => MapEntry(DBusString(kk), DBusVariant(vv))),
              ),
            ])).toList(),
          ),
        ]),
        DBusBoolean(installProprietary),
        DBusBoolean(installRecommendedDrivers),
      ],
    );

    return (
      (reply.returnValues[0] as DBusUint32).value,
      (reply.returnValues[1] as DBusArray)
          .children
          .cast<DBusString>()
          .map((s) => s.value)
          .toList(),
    );
  }

  Future<void> beginInstallation(int planId) =>
      object.callMethod(interface, 'BeginInstallation', [DBusUint32(planId)]);

  Future<void> setCurrentLocale(String locale) =>
      object.setProperty(interface, kCurrentLocale, DBusString(locale));

  Future<void> setCurrentTimezone(String timezone) =>
      object.setProperty(interface, kCurrentTimezone, DBusString(timezone));

  Future<void> setCurrentKeyboardLayout(List<DBusValue> layout) =>
      object.setProperty(interface, kCurrentKeyboardLayout, DBusStruct(layout));

  Future<String> get state async =>
      (await object.getProperty(interface, kState)).asString();

  Future<String> get errorMessage async =>
      (await object.getProperty(interface, kErrorMessage)).asString();

  Future<(String, double, String)> get progress async =>
      (await object.getProperty(interface, kProgress)).asStruct().length == 3
          ? (
              (await object.getProperty(interface, kCurrentKeyboardLayout)).asStruct()[0].asString(),
              (await object.getProperty(interface, kCurrentKeyboardLayout)).asStruct()[1].asDouble(),
              (await object.getProperty(interface, kCurrentKeyboardLayout)).asStruct()[2].asString(),
            )
          : ('', 0.0, '');

  Future<String> get currentLocale async =>
      (await object.getProperty(interface, kCurrentLocale)).asString();

  Future<String> get currentTimezone async =>
      (await object.getProperty(interface, kCurrentTimezone)).asString();

  Future<(String, String)> get currentKeyboardLayout async =>
      (await object.getProperty(interface, kCurrentKeyboardLayout)).asStruct().length == 2
          ? (
              (await object.getProperty(interface, kCurrentKeyboardLayout)).asStruct()[0].asString(),
              (await object.getProperty(interface, kCurrentKeyboardLayout)).asStruct()[1].asString(),
            )
          : ('', '');
}
