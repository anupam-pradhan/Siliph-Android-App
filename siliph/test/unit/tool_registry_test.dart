/// Unit tests for the central tool registry (sections 6, 115).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:siliph/app/router.dart';
import 'package:siliph/domain/models/tool_category.dart';
import 'package:siliph/domain/models/tool_definition.dart';
import 'package:siliph/domain/services/tool_registry.dart';

void main() {
  const registry = ToolRegistry();

  group('ToolRegistry', () {
    test('has a non-empty catalog', () {
      expect(registry.all, isNotEmpty);
    });

    test('tool ids are unique', () {
      final ids = registry.all.map((t) => t.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'duplicate tool ids found');
    });

    test('every tool has a non-empty title and subtitle', () {
      for (final tool in registry.all) {
        expect(tool.title.trim(), isNotEmpty, reason: 'empty title on ${tool.id}');
        expect(tool.subtitle.trim(), isNotEmpty, reason: 'empty subtitle on ${tool.id}');
      }
    });

    test('byId resolves known tools and returns null for unknown', () {
      expect(registry.byId('compress-pdf'), isNotNull);
      expect(registry.byId('does-not-exist'), isNull);
    });

    test('quickActions all resolve to registered tools', () {
      final quick = registry.quickActions;
      expect(quick, isNotEmpty);
      for (final tool in quick) {
        expect(registry.byId(tool.id), isNotNull);
      }
    });

    test('inCategory filters correctly', () {
      final scanners = registry.inCategory(ToolCategory.scanner);
      expect(scanners, isNotEmpty);
      expect(scanners.every((t) => t.category == ToolCategory.scanner), isTrue);
    });

    test('camera tools are flagged requiresCamera', () {
      final scan = registry.byId('scan-document')!;
      expect(scan.requiresCamera, isTrue);
    });

    test('every ready tool has a wired workflow route (no dead buttons)',
        () {
      for (final tool in registry.all) {
        if (tool.availability == ToolAvailability.ready) {
          expect(
            SiliphRoutes.workflowFor(tool.id),
            isNotNull,
            reason: 'ready tool ${tool.id} has no workflow route',
          );
        }
      }
    });
  });
}
