/// Unit tests for the crop rectangle math used by the Crop Image screen
/// (section 50).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:siliph/features/images/crop_image_screen.dart';

void main() {
  group('centerCropRect', () {
    test('null ratio keeps the whole image', () {
      expect(centerCropRect(4000, 3000, null), (0, 0, 4000, 3000));
    });

    test('square crop trims the wider dimension symmetrically', () {
      // 4000x3000 -> 3000x3000 centred: (4000-3000)/2 = 500.
      expect(centerCropRect(4000, 3000, 1), (500, 0, 3000, 3000));
    });

    test('portrait crop trims the width symmetrically', () {
      // 3000x4000 at 9:16 -> width = 4000 * 9/16 = 2250, centred.
      final (left, top, width, height) = centerCropRect(3000, 4000, 9 / 16);
      expect(width, 2250);
      expect(height, 4000);
      expect(left, (3000 - 2250) ~/ 2);
      expect(top, 0);
    });

    test('exact aspect match changes nothing', () {
      expect(centerCropRect(1600, 900, 16 / 9), (0, 0, 1600, 900));
    });
  });
}
