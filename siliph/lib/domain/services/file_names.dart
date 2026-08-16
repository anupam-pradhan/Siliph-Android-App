/// Pure file-name validation for rename flows (section 34).
///
/// No Flutter imports: unit-testable and reusable by batch rename later.
library;

/// Returns a user-facing problem with [name], or null when it is usable.
String? renameProblem(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return 'Enter a file name.';
  if (trimmed == '.' || trimmed == '..') return 'That name is not allowed.';
  if (trimmed.contains('/') || trimmed.contains('\u0000')) {
    return 'File names cannot contain slashes.';
  }
  if (trimmed.length > 200) return 'That name is too long.';
  return null;
}

/// True when [name] is unchanged apart from surrounding whitespace.
bool isEffectivelyUnchanged(String name, String currentName) =>
    name.trim() == currentName;

/// Splits a display name into base + extension (extension keeps the dot).
///
/// `Report.PDF` -> (`Report`, `.PDF`); `archive` -> (`archive`, '').
/// Hidden files like `.gitignore` keep their whole name as the base.
(String, String) splitExtension(String name) {
  final dot = name.lastIndexOf('.');
  if (dot <= 0 || dot == name.length - 1) return (name, '');
  return (name.substring(0, dot), name.substring(dot));
}
