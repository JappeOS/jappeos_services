import 'package:dbus/dbus.dart';
import 'package:logging/logging.dart';

import '../../../logger.dart';
import '../../../utils/dbus/object_collection.dart';
import '../../../utils/dbus/property_watcher.dart';
import '../../../utils/dbus/service_watcher.dart';
import '../../service.dart';
import '../dbus/audio_service_proxy.dart';
import '../model/audio_device.dart';
import '../model/audio_stream.dart';
import 'audio_device_controller.dart';
import 'audio_stream_controller.dart';

class AudioService extends Service {
  final Logger log = createLogger('AudioService');
  late final AudioServiceProxy _proxy;
  late final DbusObjectCollection<AudioDevice, AudioDeviceController> _devices;
  late final DbusObjectCollection<AudioStream, AudioStreamController> _streams;
  late final DbusPropertyWatcher _properties;
  DBusObjectPath _activeInputDevice = DBusObjectPath.root;
  DBusObjectPath _activeOutputDevice = DBusObjectPath.root;

  AudioService() : super(ServiceType.session) {
    _proxy = AudioServiceProxy(client);
    _devices = DbusObjectCollection(
      object: _proxy.object,
      interface: AudioServiceProxy.interface,
      addedSignal: 'DeviceAdded',
      removedSignal: 'DeviceRemoved',
      enumerate:
          (object) async =>
              (await object.callMethod(
                AudioServiceProxy.interface,
                'ListDevices',
                [],
                replySignature: DBusSignature('ao'),
              )).returnValues[0].asObjectPathArray().toList(),
      createController:
          (path, owner) =>
              AudioDeviceController(client, path, serviceName: owner),
      onChanged: notifyListeners,
      onError: _onError,
    );
    _streams = DbusObjectCollection(
      object: _proxy.object,
      interface: AudioServiceProxy.interface,
      addedSignal: 'StreamAdded',
      removedSignal: 'StreamRemoved',
      enumerate:
          (object) async =>
              (await object.callMethod(
                AudioServiceProxy.interface,
                'ListStreams',
                [],
                replySignature: DBusSignature('ao'),
              )).returnValues[0].asObjectPathArray().toList(),
      createController:
          (path, owner) =>
              AudioStreamController(client, path, serviceName: owner),
      onChanged: notifyListeners,
      onError: _onError,
    );
    _properties = DbusPropertyWatcher(
      object: _proxy.object,
      interface: AudioServiceProxy.interface,
      onChanged: (properties) {
        _activeInputDevice =
            properties[AudioServiceProxy.kActiveInputDevice]?.asObjectPath() ??
            DBusObjectPath.root;
        _activeOutputDevice =
            properties[AudioServiceProxy.kActiveOutputDevice]?.asObjectPath() ??
            DBusObjectPath.root;
        notifyListeners();
      },
      onUnavailable: () {
        _activeInputDevice = DBusObjectPath.root;
        _activeOutputDevice = DBusObjectPath.root;
        notifyListeners();
      },
      onError: _onError,
    );

    initializeResources([
      _devices.resource,
      _streams.resource,
      _properties.resource,
    ]);
  }

  void _onError(Object error, StackTrace stack) {
    if (mounted) log.severe('Audio watch failed', error, stack);
  }

  List<AudioDevice> get devices => _devices.values;
  List<AudioStream> get streams => _streams.values;
  AudioDevice? get activeInputDevice => _devices[_activeInputDevice];
  AudioDevice? get activeOutputDevice => _devices[_activeOutputDevice];

  /// Retained for callers that need to wait for another session service.
  Future<void> waitForService(DBusClient client, String name) =>
      waitForDbusService(client, name);

  @override
  void dispose() {
    _properties.dispose();
    _devices.dispose();
    _streams.dispose();
    super.dispose();
  }

  // Service methods

  Future<void> setActiveInputDevice(AudioDevice device) =>
      _proxy.setActiveInputDevice(device.path);

  Future<void> setActiveOutputDevice(AudioDevice device) =>
      _proxy.setActiveOutputDevice(device.path);

  Future<void> setDeviceVolume(AudioDevice device, double volume) async {
    final controller = _devices.controller(device.path);
    await controller!.setVolume(volume);
  }

  Future<void> setDeviceMuted(AudioDevice device, bool muted) async {
    final controller = _devices.controller(device.path);
    await controller!.setMuted(muted);
  }

  Future<void> setStreamDevice(AudioStream stream, AudioDevice device) async {
    final controller = _streams.controller(stream.path);
    await controller!.setDevice(device.path);
  }

  Future<void> setStreamVolume(AudioStream stream, double volume) async {
    final controller = _streams.controller(stream.path);
    await controller!.setVolume(volume);
  }

  Future<void> setStreamMuted(AudioStream stream, bool muted) async {
    final controller = _streams.controller(stream.path);
    await controller!.setMuted(muted);
  }
}
