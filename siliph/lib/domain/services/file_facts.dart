/// Pure display helpers for file facts (section 34).
///
/// No Flutter imports: unit-testable.
library;

import '../models/file_item.dart';

/// `2026-08-16 14:05` style local timestamp; 'Unknown' when unset.
String formatModifiedMillis(int millis) {
  if (millis <= 0) return 'Unknown';
  final dt = DateTime.fromMillisecondsSinceEpoch(millis);
  String two(int v) => v.toString().padLeft(2, '0');
  return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
      '${two(dt.hour)}:${two(dt.minute)}';
}

/// The provider authority of a content URI ('com.android.providers...'),
/// or empty when the URI is not a content URI.
String providerAuthority(String uri) {
  const scheme = 'content://';
  if (!uri.startsWith(scheme)) return '';
  final rest = uri.substring(scheme.length);
  final slash = rest.indexOf('/');
  return slash < 0 ? rest : rest.substring(0, slash);
}

/// Short, human hint about where a tree URI points. Keeps the trailing
/// document id segment which usually names the folder.
String folderHint(String treeUri) {
  final segments = Uri.tryParse(treeUri)?.pathSegments ?? const [];
  if (segments.isEmpty) return treeUri;
  final last = Uri.decodeComponent(segments.last);
  return last.split(':').last;
}

/// Human-readable byte size ('512B', '1.2MB'); negative becomes 'Unknown'.
String formatBytes(int bytes) {
  if (bytes < 0) return 'Unknown';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  double value = bytes.toDouble();
  int unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return unit == 0
      ? '${bytes}B'
      : '${value.toStringAsFixed(value >= 100 ? 0 : 1)}${units[unit]}';
}

/// Best-effort display name for a document URI: the decoded last path
/// segment, minus any 'primary:'-style document-id prefix and directory
/// parts ('primary:Documents/photo.jpg' -> 'photo.jpg').
String displayNameFromUri(String uri) {
  final segments = Uri.tryParse(uri)?.pathSegments ?? const [];
  if (segments.isEmpty) return uri;
  var last = Uri.decodeComponent(segments.last).split(':').last;
  final slash = last.lastIndexOf('/');
  if (slash >= 0) last = last.substring(slash + 1);
  return last.isEmpty ? uri : last;
}

/// 'photo.jpg' -> 'photo' (best-effort, for building output names).
String baseName(FileItem file) {
  final dot = file.displayName.lastIndexOf('.');
  return dot > 0 ? file.displayName.substring(0, dot) : file.displayName;
}
