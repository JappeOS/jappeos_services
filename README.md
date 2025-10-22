# jappeos_services

A service system that allows easy access to the jappeos_core systemd service using D-Bus.

## Usage

Jappeos_services makes it easy to access things like the audio system in an unified way, regardless of the actual backend (e.g. pipewire, pulseaudio, etc.). This means that the backend can be easily swapped from pipewire to pulseaudio for example.

This system is used in the JappeOS desktop environment to control system volume, connect to the internet, use the Bluetooth and more.
It is also used by the applications that need access to the system, like the settings app.

This is used just like a regular provider in Flutter, using the `provider` package.
Use the `JappeosServiceProvider` widget to register the services, and then use them like any other provider in your widgets.

Other non-JappeOS apps that use the underlying APIs (e.g. pulseaudio) directly will still work, but swapping the backend might break them.

## Platform

This package is designed to work on Linux, and is not supposed to be used on any other platform.