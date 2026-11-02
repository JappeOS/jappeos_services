<h1 align="center">
  <img src="https://raw.githubusercontent.com/JappeOS/JappeOS/dev/Icons/jappeos-logo-banner-white-512.png" width="120"><br>
  jappeos_services
</h1>

<p align="center">
  <strong>A service system that allows easy access to the jappeos_core systemd service using D-Bus.</strong>
</p>

<p align="center">
  <a href="./issues"><img src="https://img.shields.io/github/issues/JappeOS/jappeos_services?style=plastic&color=edda09"></a>
  <a href="./pulls"><img src="https://img.shields.io/github/issues-pr/JappeOS/jappeos_services?style=plastic&color=40a842"></a>
  <a href="./LICENSE"><img src="https://img.shields.io/github/license/JappeOS/jappeos_services?style=plastic&color=9d09ed"></a>
  <img src="https://img.shields.io/badge/arch-x86__64-blue?style=plastic">
  <img src="https://img.shields.io/badge/status-experimental-orange?style=plastic">
  <a href="https://discord.gg/dRtU4HR"><img src="https://img.shields.io/discord/716673375946407972?style=plastic&color=3250a8"></a>
</p>

---

## Overview

`jappeos_services` makes it easy to access things like the audio system in an unified way, regardless of the actual backend (e.g. pipewire, pulseaudio, etc.). This means that the backend can be easily swapped from pipewire to pulseaudio for example.

This system is used in the JappeOS desktop environment to control system volume, connect to the internet, use the Bluetooth and more.
It is also used by the applications that need access to the system, like the settings app.

This is used just like a regular provider in Flutter, using the `provider` package.
Use the `JappeosServiceProvider` widget to register the services, and then use them like any other provider in your widgets.

Other non-JappeOS apps that use the underlying APIs (e.g. pulseaudio) directly will still work, but swapping the backend might break them.

> [!WARNING]
> This package is designed to work on Linux, and is not supposed to be used on any other platform.

## Features

* Access to all `jappeos_core` D-Bus services.

## Role in the OS

Used by all Dart-written components of JappeOS that require access to system things like power management, networking, login, sessions etc.
The greeter and the desktop environment use this.

## Building

Compiles like a regular Dart project. Used as a library through pubspec. Not meant to be directly compiled.

## Shared D-Bus infrastructure

The internal helpers in `lib/src/utils/dbus/` provide shared transport and lifecycle
handling:

- `DbusClientPool` shares connections per bus and releases each connection when
  its last service is disposed. Choosing a bus is independent of choosing a
  destination; concrete proxies accept an explicit `serviceName`.
- `DbusServiceWatcher` tracks a destination's unique owner. Activation is opt-in.
  `waitForDbusService` cancels its subscription on success, failure, or timeout.
- `DbusPropertyWatcher` reads an interface with `GetAll`, applies property
  changes, and refreshes invalidated properties. It clears state and starts a
  fresh watch when the destination disappears or changes owner.
- `DbusObjectCollection` accepts service-specific enumeration and controller
  creation callbacks. It owns discovery, membership changes, controller cleanup,
  and cached models. Pending creation/loading cannot resurrect removed objects.
- `DbusObjectController` handles property subscriptions and model updates for
  individual objects. Its containing collection recreates it on owner changes.
- `WatchedSnapshot` subscribes before reading and retries a read that overlaps
  changes. Concurrent loads share one read; disposal suppresses pending results.

Collections listen for added and removed signals on the same stream to retain
wire order. Reads and property signals are pinned to the current unique owner,
so a previous daemon instance cannot overwrite replacement state. The helpers
use a bus round trip after installing listeners to order AddMatch requests
before initial reads with the current `dbus` package.

Service restart recovery assumes the D-Bus connection itself remains alive.
Reconnecting after the bus process dies requires recreating the owning services;
these utilities do not silently reconnect or replay mutating requests. Helpers
report failures through `onError` and clear unavailable state through their
callbacks. They do not promise an atomic multi-property snapshot from services
that do not provide one, and require the remote service to emit change signals.

## Testing

Run `flutter test` for deterministic lifecycle tests and integration tests on a
private in-process D-Bus server. These tests do not contact host system services.

## Contributing

Contributions of all kinds are welcome and appreciated. You can help the project by:

- ⭐ Starring the repository to show your support
- 💖 Sponsoring the project (if available)
- 🐞 Reporting bugs via [GitHub Issues](./issues)
- 💡 Requesting or discussing new features

For code contributions, please see [`CONTRIBUTING.md`](./CONTRIBUTING.md) for guidelines.

## License

This repository is part of the JappeOS project and is licensed under the terms described in the [`LICENSE`](./LICENSE) file.
