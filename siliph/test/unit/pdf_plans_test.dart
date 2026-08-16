/// Unit tests for the pure PDF planning helpers (section 60).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:siliph/domain/services/pdf_plans.dart';

void main() {
  group('splitPlan', () {
    test('even division', () {
      expect(
        splitPlan(6, 2),
        const [PageRange(1, 2), PageRange(3, 4), PageRange(5, 6)],
      );
    });

    test('last partial range', () {
      expect(
        splitPlan(7, 3),
        const [PageRange(1, 3), PageRange(4, 6), PageRange(7, 7)],
      );
    });

    test('every N larger than document is one part', () {
      expect(splitPlan(4, 10), const [PageRange(1, 4)]);
    });

    test('guards against invalid input', () {
      expect(splitPlan(0, 2), isEmpty);
      expect(splitPlan(5, 0), isEmpty);
      expect(splitPlan(5, -1), isEmpty);
    });
  });

  group('clampRange', () {
    test('clamps out-of-bounds values', () {
      expect(clampRange(10, -3, 25), const PageRange(1, 10));
    });

    test('keeps valid ranges', () {
      expect(clampRange(10, 2, 8), const PageRange(2, 8));
    });

    test('inverted input collapses to the clamped first page', () {
      expect(clampRange(10, 8, 2), const PageRange(8, 8));
    });

    test('empty document yields null', () {
      expect(clampRange(0, 1, 2), isNull);
    });
  });

  group('orderWithout', () {
    test('removes one-based pages', () {
      expect(orderWithout(5, {2, 4}), [0, 2, 4]);
    });

    test('returns null when everything is deleted', () {
      expect(orderWithout(2, {1, 2}), isNull);
    });
  });

  group('partName', () {
    test('single part keeps a simple suffix', () {
      expect(partName('Report.PDF', part: 1, of: 1), 'Report-output.pdf');
    });

    test('multi part numbers each file', () {
      expect(partName('Report.pdf', part: 2, of: 5), 'Report-part-2-of-5.pdf');
    });

    test('handles names without extension', () {
      expect(partName('scan', part: 1, of: 3), 'scan-part-1-of-3.pdf');
    });
  });

  test('PageRange.toZeroBasedOrder', () {
    expect(const PageRange(3, 5).toZeroBasedOrder(), [2, 3, 4]);
  });
}
