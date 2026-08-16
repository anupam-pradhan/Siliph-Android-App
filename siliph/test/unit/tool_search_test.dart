/// Unit tests for the local tool search ranking (section 159).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:siliph/domain/services/tool_registry.dart';
import 'package:siliph/domain/services/tool_search.dart';

void main() {
  const registry = ToolRegistry();
  final search = ToolSearch(registry.all);

  group('ToolSearch', () {
    test('empty query returns the full catalog', () {
      final results = search.search('');
      expect(results.length, registry.all.length);
      expect(search.search('   ').length, registry.all.length);
    });

    test('exact title match outranks partial matches', () {
      final results = search.search('compress pdf');
      expect(results, isNotEmpty);
      expect(results.first.id, 'compress-pdf');
    });

    test('alias "reduce pdf" finds Compress PDF', () {
      final results = search.search('reduce pdf');
      expect(results.any((t) => t.id == 'compress-pdf'), isTrue);
    });

    test('alias "make picture smaller" finds Compress Image', () {
      final results = search.search('make picture smaller');
      expect(results.any((t) => t.id == 'compress-image'), isTrue);
    });

    test('"scan" surfaces scanner tools', () {
      final results = search.search('scan');
      expect(results, isNotEmpty);
      expect(results.any((t) => t.id == 'scan-document'), isTrue);
    });

    test('search is case-insensitive', () {
      final lower = search.search('merge');
      final upper = search.search('MERGE');
      expect(lower.map((t) => t.id), upper.map((t) => t.id));
    });

    test('favorites are boosted within equal relevance', () {
      final baseline = search.search('pdf');
      final boosted = search.search('pdf', favoriteIds: {'pdf-metadata'});
      // The favorited tool must not rank worse than in the baseline.
      final baseIndex = baseline.indexWhere((t) => t.id == 'pdf-metadata');
      final boostedIndex = boosted.indexWhere((t) => t.id == 'pdf-metadata');
      expect(boostedIndex, lessThanOrEqualTo(baseIndex));
    });

    test('no match returns empty list', () {
      expect(search.search('zzz-no-such-tool'), isEmpty);
    });
  });
}
