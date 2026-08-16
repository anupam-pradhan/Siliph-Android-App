/// Widget tests for the image tool workflows: compress, exact-KB, resize,
/// crop, convert, remove-EXIF (sections 10, 12, 50).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siliph/app/theme/siliph_theme.dart';
import 'package:siliph/domain/models/file_item.dart';
import 'package:siliph/domain/providers.dart';
import 'package:siliph/domain/services/native_bridge.dart';
import 'package:siliph/features/images/compress_image_screen.dart';
import 'package:siliph/features/images/convert_image_screen.dart';
import 'package:siliph/features/images/crop_image_screen.dart';
import 'package:siliph/features/images/exact_kb_screen.dart';
import 'package:siliph/features/images/remove_exif_screen.dart';
import 'package:siliph/features/images/resize_image_screen.dart';

import 'fake_gateways.dart';

const _photo = FileItem(
  uri: 'content://test/photo.jpg',
  displayName: 'photo.jpg',
  sizeBytes: 3 * 1024 * 1024,
);

Widget _app(
  FakeFileGateway files,
  FakeImageToolsGateway images,
  Widget home,
) {
  return ProviderScope(
    overrides: [
      fileGatewayProvider.overrideWithValue(files),
      imageToolsGatewayProvider.overrideWithValue(images),
    ],
    child: MaterialApp(theme: SiliphTheme.build(), home: home),
  );
}

Future<void> _tapAndSettle(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  group('Compress Image', () {
    testWidgets('Re-encodes at the chosen quality', (tester) async {
      final files = FakeFileGateway()..nextOpen = [_photo];
      final images = FakeImageToolsGateway();

      await tester.pumpWidget(
          _app(files, images, const CompressImageScreen()));
      await _tapAndSettle(tester, 'Choose image');

      await tester.tap(find.text('WebP'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save compressed image'));
      await tester.pump();
      await images.finishRunningTask();
      await tester.pumpAndSettle();

      expect(images.compressCalls, 1);
      expect(images.lastCompressFormat, 'webp');
      expect(images.lastCompressQuality, 70);
      expect(files.createRequests, ['photo-compressed.webp']);
      expect(find.text('Image compressed'), findsOneWidget);
    });
  });

  group('Exact KB', () {
    testWidgets('Compresses to the entered target', (tester) async {
      final files = FakeFileGateway()..nextOpen = [_photo];
      final images = FakeImageToolsGateway();

      await tester.pumpWidget(_app(files, images, const ExactKbScreen()));
      await _tapAndSettle(tester, 'Choose image');

      await tester.enterText(
          find.widgetWithText(TextField, '100'), '150');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save at target size'));
      await tester.pump();
      await images.finishRunningTask();
      await tester.pumpAndSettle();

      expect(images.compressToKbCalls, 1);
      expect(images.lastTargetKb, 150);
      expect(files.createRequests, ['photo-150kb.jpg']);
      expect(find.text('Target size reached'), findsOneWidget);
    });

    testWidgets('Rejects targets below 10 KB', (tester) async {
      final files = FakeFileGateway()..nextOpen = [_photo];
      final images = FakeImageToolsGateway();

      await tester.pumpWidget(_app(files, images, const ExactKbScreen()));
      await _tapAndSettle(tester, 'Choose image');
      await tester.enterText(
          find.widgetWithText(TextField, '100'), '5');
      await tester.pumpAndSettle();

      expect(find.text('Enter a target'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed,
        isNull,
      );
    });
  });

  group('Resize Image', () {
    testWidgets('Keeps the aspect ratio locked while editing', (tester) async {
      final files = FakeFileGateway()..nextOpen = [_photo];
      final images = FakeImageToolsGateway();

      await tester.pumpWidget(
          _app(files, images, const ResizeImageScreen()));
      await _tapAndSettle(tester, 'Choose image');

      expect(images.inspectCalls, 1);
      expect(find.text('Original 4000×3000 px'), findsOneWidget);

      await tester.enterText(
          find.widgetWithText(TextField, 'Width px'), '800');
      await tester.pumpAndSettle();

      // Locked ratio: 800 / (4000/3000) = 600.
      expect(find.widgetWithText(TextField, '600'), findsOneWidget);

      await tester.tap(find.text('Save resized image'));
      await tester.pump();
      await images.finishRunningTask();
      await tester.pumpAndSettle();

      expect(images.resizeCalls, 1);
      expect(images.lastResizeWidth, 800);
      expect(images.lastResizeHeight, 600);
      expect(find.text('Image resized'), findsOneWidget);
    });
  });

  group('Crop Image', () {
    testWidgets('Centre-crops to the chosen aspect ratio', (tester) async {
      final files = FakeFileGateway()..nextOpen = [_photo];
      final images = FakeImageToolsGateway();

      await tester.pumpWidget(_app(files, images, const CropImageScreen()));
      await _tapAndSettle(tester, 'Choose image');

      await _tapAndSettle(tester, '1:1');
      // 4000x3000 -> 3000x3000 centred: left = 500.
      expect(find.textContaining('3000×3000 px, centred'), findsOneWidget);

      await tester.tap(find.text('Save cropped image'));
      await tester.pump();
      await images.finishRunningTask();
      await tester.pumpAndSettle();

      expect(images.cropCalls, 1);
      expect(images.lastCropRect, (500, 0, 3000, 3000));
      expect(find.text('Image cropped'), findsOneWidget);
    });
  });

  group('Convert Image', () {
    testWidgets('Converts to the selected format', (tester) async {
      final files = FakeFileGateway()..nextOpen = [_photo];
      final images = FakeImageToolsGateway();

      await tester.pumpWidget(
          _app(files, images, const ConvertImageScreen()));
      await _tapAndSettle(tester, 'Choose image');

      await tester.tap(find.text('PNG'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save as PNG'));
      await tester.pump();
      await images.finishRunningTask();
      await tester.pumpAndSettle();

      expect(images.convertCalls, 1);
      expect(images.lastConvertFormat, 'png');
      expect(files.createRequests, ['photo.png']);
      expect(find.text('Image converted'), findsOneWidget);
    });
  });

  group('Remove EXIF', () {
    testWidgets('Saves a metadata-free JPEG copy', (tester) async {
      final files = FakeFileGateway()..nextOpen = [_photo];
      final images = FakeImageToolsGateway();

      await tester.pumpWidget(_app(files, images, const RemoveExifScreen()));
      await _tapAndSettle(tester, 'Choose image');

      // Honest copy about the re-encode is shown before running.
      expect(find.textContaining('Nothing but'), findsOneWidget);

      await tester.tap(find.text('Save metadata-free copy'));
      await tester.pump();
      await images.finishRunningTask();
      await tester.pumpAndSettle();

      expect(images.stripExifCalls, 1);
      expect(files.createRequests, ['photo-clean.jpg']);
      expect(find.text('Metadata removed'), findsOneWidget);
    });

    testWidgets('Reports inspection failures when picking a non-image',
        (tester) async {
      final files = FakeFileGateway()..nextOpen = [_photo];
      final images = FakeImageToolsGateway()
        ..inspectError = const BridgeException(
            'invalid_input', 'That file is not a decodable image');

      // Only resize/crop inspect after picking; use resize here.
      await tester.pumpWidget(
          _app(files, images, const ResizeImageScreen()));
      await _tapAndSettle(tester, 'Choose image');

      expect(
          find.text('That file is not a decodable image'), findsOneWidget);
    });
  });
}
