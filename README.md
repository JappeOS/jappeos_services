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

## Power management

`PowerManagerService` reads battery information directly from UPower and sends
power actions directly to systemd-logind over the system bus. It no longer uses
the C++ core power interface. Existing `devices`, `shutdown()`, `reboot()`, and
`suspend()` calls remain available, and `hibernate()` is now supported.

`devices` contains UPower's enumerated physical power devices, including mains
and peripheral devices. The nullable `displayDevice` is UPower's composite
battery/UPS status for a desktop indicator; it is separate from `devices` and
is null when unavailable or when UPower marks it as not present. Device IDs
retain the previous mapping to UPower's `Serial` (which can be empty). Percentage
is 0–100; zero time estimates mean unknown. Unknown numeric type/state values
map to the existing `unknown` enum members. Snapshots use one `GetAll` request.

`canShutdown()`, `canReboot()`, `canSuspend()`, and `canHibernate()` query logind
on demand and return `PowerActionCapability`: `allowed`,
`authenticationRequired`, `denied`, `unsupported`, or `unknown`.

```dart
final power = context.read<PowerManagerService>();
final capability = await power.canHibernate();
if (capability == PowerActionCapability.allowed) {
  await power.hibernate();
} else if (capability == PowerActionCapability.authenticationRequired) {
  await power.hibernate(interactive: true);
}
```

All four actions default to `interactive: false`. Passing `interactive: true`
permits polkit to request authentication through a session authentication agent.
Logind now authorizes the actual application caller, so desktop and greeter
permissions follow logind/polkit policy. Capability queries are advisory:
actions can still fail if policy, inhibitors, sessions, or system state change.
D-Bus errors propagate to callers; there is no privileged fallback or automatic
retry. Hibernation requires working kernel, swap/resume, and systemd sleep
configuration. This library does not configure those prerequisites.

The optional `busClient` constructor argument accepts a concrete borrowed D-Bus
connection for testing. Disposing the provider does not close a borrowed client.
Tests exercise the provider against UPower and logind test objects on a private
bus, without executing host shutdown or sleep actions. Actual hibernation and
greeter authorization should be validated in a JappeOS VM or test device.

Protocol references: [UPower](https://upower.freedesktop.org/docs/UPower.html),
[UPower device properties](https://upower.freedesktop.org/docs/Device.html), and
[logind](https://freedesktop.org/software/systemd/man/latest/org.freedesktop.login1.html).

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


### Service readiness and recovery

The installer, audio, network and UPower providers expose `status`,
`initializationError`, `generation`, `init()` and `retryInitialization()` through
`Service`. `init()` completes only after their watched data has loaded and throws
on failure; it no longer treats a logged initialization error as success.
Automatic constructor startup consumes that error while retaining it in status.
Legacy providers without registered watches are not covered by this readiness contract.
Power action methods remain independent of UPower readiness.

Shared property watchers and collections use `DbusResource` for activation,
owner changes, a configurable 30-second readiness deadline and explicit retry.
They continue watching after failure and recover when a new owner appears.
Owner replacement, timeout and disposal invalidate pending reads. Only discovery
and reads are restarted; mutating requests are never replayed. A disconnected bus
connection itself is not recreated by these watchers.

New providers register their watch resources with `initializeResources(...)`;
they should not duplicate init futures, activation loops or error-catching code.
Use `generation` to invalidate application-owned snapshots/plans. A service's
readiness status is separate from its domain state (e.g. installation running).
