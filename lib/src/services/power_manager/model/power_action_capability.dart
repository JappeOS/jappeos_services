/// A point-in-time logind authorization/support check. The subsequent action
/// can still fail if policy, sessions, or inhibitors change.
enum PowerActionCapability {
  allowed,
  authenticationRequired,
  denied,
  unsupported,
  unknown;

  static PowerActionCapability fromLogind(String value) => switch (value) {
    'yes' => allowed,
    'challenge' => authenticationRequired,
    'no' => denied,
    'na' => unsupported,
    _ => unknown,
  };
}
