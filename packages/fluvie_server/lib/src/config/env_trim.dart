/// Normalizes an environment value: trims it, and treats null, empty, and
/// whitespace-only as unset.
///
/// Every config reader in this package goes through this one helper so "set to
/// blank" and "not set" mean the same thing everywhere.
String? trimToNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
