import 'package:dbus/dbus.dart';

extension EnumByNameExt<T extends Enum> on Iterable<T> {
  /// Finds the enum value in this list with name [name].
  ///
  /// Goes through this collection looking for an enum with
  /// name [name], as reported by [EnumName.name].
  /// Returns the first value with the given name, or null if not found.
  T? byNameOrNull(String name) {
    for (var value in this) {
      if (value.name == name) return value;
    }
    return null;
  }
}

extension DBusObjectPathExt on DBusObjectPath {
  /// Shortens a DBus object path for display purposes.
  String shortenForDisplay() {
    final parts = split();
    final shortenedParts = <String>[];

    for (int i = 0; i < parts.length; i++) {
      final part = parts[i];

      // Skip empty parts (like the first element from leading '/')
      if (part.isEmpty) {
        continue;
      }

      String shortened;

      // Check if the part is entirely lowercase
      if (part == part.toLowerCase()) {
        // First part ("com") - keep fully
        if (i == 1) {
          shortened = part;
        } else {
          // Take first two characters
          shortened = part.length >= 2 ? part.substring(0, 2) : part;
        }
      } else {
        // Part contains uppercase letters (PascalCase or camelCase)
        final uppercaseLetters = <String>[];

        // Collect uppercase letters
        for (int j = 0; j < part.length; j++) {
          if (part[j] == part[j].toUpperCase() && part[j] != part[j].toLowerCase()) {
            uppercaseLetters.add(part[j].toLowerCase());
            if (uppercaseLetters.length >= 3) break;
          }
        }

        // If we found uppercase letters, use them
        if (uppercaseLetters.isNotEmpty) {
          shortened = uppercaseLetters.join('');

          // Ensure at least 2 chars if the original part has 2+ chars
          if (shortened.length == 1 && part.length >= 2) {
            // Add the first lowercase letter after the first uppercase
            for (int j = 1; j < part.length && shortened.length < 2; j++) {
              if (part[j] == part[j].toLowerCase() && part[j] != part[j].toUpperCase()) {
                shortened += part[j];
                break;
              }
            }
          }
        } else {
          // No uppercase found, treat as lowercase
          shortened = part.length >= 2 ? part.substring(0, 2).toLowerCase() : part.toLowerCase();
        }
      }

      shortenedParts.add(shortened);
    }

    return '/${shortenedParts.join('/')}';
  }
}

extension IterableReplaceWhere<E> on Iterable<E> {
  Iterable<E> replaceWhere(bool Function(E) test, E Function(E) replace) =>
      map((e) => test(e) ? replace(e) : e);
  Iterable<E> replaceWhereNot(bool Function(E) test, E Function(E) replace) =>
      map((e) => test(e) ? e : replace(e));
}