/// Scanner history provider.
///
/// Tracks recently scanned documents for the Recent screen.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/file_item.dart';

/// A scan record in the history.
class ScanRecord {
  const ScanRecord({
    required this.file,
    required this.pageCount,
    required this.scannedAt,
    this.scanMode = 'document',
  });

  final FileItem file;
  final int pageCount;
  final DateTime scannedAt;
  final String scanMode;
}

/// In-memory scanner history (most recent first, max 50).
class ScanHistoryNotifier extends Notifier<List<ScanRecord>> {
  static const int _max = 50;

  @override
  List<ScanRecord> build() => const [];

  void record(ScanRecord entry) {
    state = [entry, ...state.where((e) => e.file.uri != entry.file.uri)]
        .take(_max)
        .toList();
  }

  void remove(String uri) {
    state = state.where((e) => e.file.uri != uri).toList();
  }

  void clear() {
    state = [];
  }
}

final scanHistoryProvider =
    NotifierProvider<ScanHistoryNotifier, List<ScanRecord>>(
  ScanHistoryNotifier.new,
);
