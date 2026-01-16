class WifiAccessPoint {
  final String ssid;
  final int strength;
  final String security;
  final int frequency;
  final bool connected;

  WifiAccessPoint({
    required this.ssid,
    required this.strength,
    required this.security,
    required this.frequency,
    required this.connected,
  });
}
