/// A user-facing document addressed by a content URI (sections 5, 180).
///
/// Wraps the generated [FileMeta] with display helpers. Never assumes a
/// content URI can be converted to a filesystem path.
library;

import 'package:flutter/foundation.dart';

import '../../generated/siliph_bridge.g.dart';

@immutable
class FileItem {
  const FileItem({
    required this.uri,
    required this.displayName,
    this.mimeType,
    this.sizeBytes = -1,
    this.lastModifiedMillis = 0,
  });

  factory FileItem.fromMeta(FileMeta meta) => FileItem(
        uri: meta.uri,
        displayName: meta.displayName,
        mimeType: meta.mimeType,
        sizeBytes: meta.sizeBytes,
        lastModifiedMillis: meta.lastModifiedMillis,
      );

  final String uri;
  final String displayName;
  final String? mimeType;
  final int sizeBytes;
  final int lastModifiedMillis;

  /// True for SAF directory entries (DocumentsContract MIME type).
  bool get isDirectory => mimeType == 'vnd.android.document/directory';

  /// Lower-case extension without the dot ('pdf', 'jpg'); empty when none.
  String get extension {
    final dot = displayName.lastIndexOf('.');
    if (dot <= 0 || dot == displayName.length - 1) return '';
    return displayName.substring(dot + 1).toLowerCase();
  }

  /// Human-readable size; empty when unknown.
  String get formattedSize {
    if (sizeBytes < 0) return '';
    const units = ['B', 'KB', 'MB', 'GB'];
    double value = sizeBytes.toDouble();
    int unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    return unit == 0
        ? '${sizeBytes}B'
        : '${value.toStringAsFixed(value >= 100 ? 0 : 1)}${units[unit]}';
  }

  @override
  bool operator ==(Object other) =>
      other is FileItem && other.uri == uri && other.displayName == displayName;

  @override
  int get hashCode => Object.hash(uri, displayName);

  @override
  String toString() => 'FileItem($displayName, $uri)';
}
