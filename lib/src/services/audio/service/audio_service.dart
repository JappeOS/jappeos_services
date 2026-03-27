import 'dart:async';

import 'package:dbus/dbus.dart';
import 'package:logging/logging.dart';

import '../../../logger.dart';
import '../../service.dart';
import '../dbus/audio_service_proxy.dart';
import '../model/audio_device.dart';
import '../model/audio_stream.dart';
import 'audio_device_controller.dart';
import 'audio_stream_controller.dart';

class AudioService extends Service {
  final Logger log = createLogger('AudioService');
  bool _initialized = false;
  late final AudioServiceProxy _proxy;

  final Map<DBusObjectPath, AudioDeviceController> _deviceControllers = {};
  final Map<DBusObjectPath, AudioStreamController> _streamControllers = {};
  final Map<DBusObjectPath, AudioDevice> _devices = {};
  final Map<DBusObjectPath, AudioStream> _streams = {};
  DBusObjectPath _activeInputDevice = DBusObjectPath.root;
  DBusObjectPath _activeOutputDevice = DBusObjectPath.root;
  final List<StreamSubscription> _subs = [];

  AudioService() {
    _proxy = AudioServiceProxy(client);
    scheduleMicrotask(() => init());
  }

  List<AudioDevice> get devices =>
      _devices.values.toList(growable: false);

  List<AudioStream> get streams =>
      _streams.values.toList(growable: false);

  AudioDevice? get activeInputDevice => _devices[_activeInputDevice];
  AudioDevice? get activeOutputDevice => _devices[_activeOutputDevice];

  // Init

  Future<void> init() async {
    if (_initialized || !mounted) return;
    _initialized = true;

    try {
      await _loadInitialDevices();
      await _loadInitialStreams();
      _activeInputDevice = await _proxy.activeInputDevice;
      _activeOutputDevice = await _proxy.activeOutputDevice;
      _subscribeSignals();
    } catch (e, st) {
      log.severe('AudioService init failed', e, st);
    }
  }

  // Cleanup

  @override
  void dispose() {
    for (final c in _deviceControllers.values) {
      c.dispose();
    }
    for (final c in _streamControllers.values) {
      c.dispose();
    }
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  // Service methods

  Future<void> setActiveInputDevice(AudioDevice device)
      => _proxy.setActiveInputDevice(device.path);

  Future<void> setActiveOutputDevice(AudioDevice device)
      => _proxy.setActiveOutputDevice(device.path);

  // Initial load

  Future<void> _loadInitialDevices() async {
    final paths = await _proxy.listDevices();

    for (final path in paths) {
      await _addDevice(path, notify: false);
    }

    notifyListeners();
  }

  Future<void> _loadInitialStreams() async {
    final paths = await _proxy.listStreams();

    for (final path in paths) {
      await _addStream(path, notify: false);
    }

    notifyListeners();
  }

  // Signal subscriptions

  void _subscribeSignals() {
    // Object subs
    _subs.add(
      _proxy.deviceAdded().listen((path) async {
        await _addDevice(path);
      }),
    );

    _subs.add(
      _proxy.streamAdded().listen((path) async {
        await _addStream(path);
      }),
    );

    _subs.add(
      _proxy.deviceRemoved().listen((path) {
        _removeDevice(path);
      }),
    );

    _subs.add(
      _proxy.streamRemoved().listen((path) {
        _removeStream(path);
      }),
    );

    // Property subs
    _subs.add(
      _proxy.propertiesChanged().listen((props) {
        final changed = props.changedProperties;
        DBusObjectPath? activeInputDevice;
        DBusObjectPath? activeOutputDevice;

        if (changed.containsKey(AudioServiceProxy.kActiveInputDevice)) {
          activeInputDevice
              = changed[AudioServiceProxy.kActiveInputDevice]!.asObjectPath();
        }
        if (changed.containsKey(AudioServiceProxy.kActiveOutputDevice)) {
          activeOutputDevice
              = changed[AudioServiceProxy.kActiveOutputDevice]!.asObjectPath();
        }

        if (activeInputDevice == null && activeOutputDevice == null) {
          return;
        }

        if (activeInputDevice != null) {
          _activeInputDevice = activeInputDevice;
        }

        if (activeOutputDevice != null) {
          _activeOutputDevice = activeOutputDevice;
        }

        notifyListeners();
      }),
    );
  }

  // Device lifecycle

  Future<void> _addDevice(
    DBusObjectPath path, {
    bool notify = true,
  }) async {
    if (_deviceControllers.containsKey(path)) return;

    final controller = AudioDeviceController(client, path);
    _deviceControllers[path] = controller;

    controller.watch((device) {
      _devices[path] = device;
      notifyListeners();
    });

    final device = await controller.load();
    _devices[path] = device;

    if (notify) notifyListeners();
  }

  void _removeDevice(DBusObjectPath path) {
    _deviceControllers.remove(path)?.dispose();
    _devices.remove(path);
    notifyListeners();
  }

  // Stream lifecycle

  Future<void> _addStream(
    DBusObjectPath path, {
    bool notify = true,
  }) async {
    if (_streamControllers.containsKey(path)) return;

    final controller = AudioStreamController(client, path);
    _streamControllers[path] = controller;

    controller.watch((stream) {
      _streams[path] = stream;
      notifyListeners();
    });

    final stream = await controller.load();
    _streams[path] = stream;

    if (notify) notifyListeners();
  }

  void _removeStream(DBusObjectPath path) {
    _streamControllers.remove(path)?.dispose();
    _streams.remove(path);
    notifyListeners();
  }
}