/// Riverpod providers for the tool catalog, search and favorites.
///
/// State management choice: Riverpod (section 111). Business state lives in
/// controllers/notifiers, not widgets.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../generated/siliph_bridge.g.dart';
import 'models/file_item.dart';
import 'services/native_bridge.dart';
import 'services/tool_registry.dart';
import 'services/tool_search.dart';

/// The central tool registry.
final toolRegistryProvider = Provider<ToolRegistry>((ref) => const ToolRegistry());

/// Local, instant search over the catalog.
final toolSearchProvider = Provider<ToolSearch>((ref) {
  return ToolSearch(ref.watch(toolRegistryProvider).all);
});

/// Favorited tool ids. In-memory for build phase 2; persisted in phase 13.
class FavoritesNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};

  void toggle(String id) {
    final next = Set<String>.of(state);
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.add(id);
    }
    state = next;
  }

  bool contains(String id) => state.contains(id);
}

final favoritesProvider =
    NotifierProvider<FavoritesNotifier, Set<String>>(FavoritesNotifier.new);

/// Recently-used tool ids, most recent first. Bounded to avoid growth.
class RecentToolsNotifier extends Notifier<List<String>> {
  static const int _max = 8;

  @override
  List<String> build() => const [];

  void record(String id) {
    final next = <String>[id, ...state.where((e) => e != id)];
    state = next.take(_max).toList();
  }
}

final recentToolsProvider =
    NotifierProvider<RecentToolsNotifier, List<String>>(RecentToolsNotifier.new);

// ---------------------------------------------------------------------------
// Native bridge (sections 5, 60). Overridable in tests with fakes.
// ---------------------------------------------------------------------------

/// Routes native -> Flutter events. Attached once in main().
final bridgeEventRouterProvider =
    Provider<BridgeEventRouter>((ref) => BridgeEventRouter());

/// SAF / Photo Picker intake and export.
final fileGatewayProvider = Provider<FileGateway>((ref) {
  return NativeFileGateway(FileAccessApi(), ref.watch(bridgeEventRouterProvider));
});

/// PDF engine operations.
final pdfGatewayProvider = Provider<PdfGateway>((ref) {
  return NativePdfGateway(PdfApi(), ref.watch(bridgeEventRouterProvider));
});

/// File utilities (ZIP, QR, folder analysis).
final fileToolsGatewayProvider = Provider<FileToolsGateway>((ref) {
  return NativeFileToolsGateway(
      FileToolsApi(), ref.watch(bridgeEventRouterProvider));
});

/// Image tools (compress, resize, crop, convert, exact-KB, EXIF).
final imageToolsGatewayProvider = Provider<ImageToolsGateway>((ref) {
  return NativeImageToolsGateway(
      ImageToolsApi(), ref.watch(bridgeEventRouterProvider));
});

/// Files picked in this session, most recent first.
///
/// In-memory by design; the durable document library lands with the data
/// phase (section 61). Deduped by URI.
class ImportedFilesNotifier extends Notifier<List<FileItem>> {
  static const int _max = 20;

  @override
  List<FileItem> build() => const [];

  void addAll(List<FileItem> files) {
    if (files.isEmpty) return;
    final next = <FileItem>[
      ...files.reversed,
      ...state.where((e) => !files.any((f) => f.uri == e.uri)),
    ];
    state = next.take(_max).toList();
  }

  void remove(String uri) {
    state = state.where((e) => e.uri != uri).toList();
  }
}

final importedFilesProvider =
    NotifierProvider<ImportedFilesNotifier, List<FileItem>>(
        ImportedFilesNotifier.new);
