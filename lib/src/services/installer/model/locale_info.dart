class LocaleInfo {
  final Map<String, String> locales;
  final List<String> timezones;
  final KeyboardLayoutInfo keyboardLayouts;

  LocaleInfo({
    required this.locales,
    required this.timezones,
    required this.keyboardLayouts,
  });
}

class KeyboardLayoutInfo {
  final Map<String, KeyboardLayout> layouts;

  KeyboardLayoutInfo({required this.layouts});
}

class KeyboardLayout {
  final String id;
  final Map<String, String> variants;

  KeyboardLayout({required this.id, required this.variants});
}