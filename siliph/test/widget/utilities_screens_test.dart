/// Widget tests for the utility workflows: Signature Maker and
/// Passport Photo (sections 10, 12, 50).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siliph/app/theme/siliph_theme.dart';
import 'package:siliph/domain/models/file_item.dart';
import 'package:siliph/domain/providers.dart';
import 'package:siliph/domain/services/native_bridge.dart';
import 'package:siliph/features/passport/passport_photo_screen.dart';
import 'package:siliph/features/signature/signature_maker_screen.dart';

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

/// Draws a stroke on the signature canvas with a raw gesture so the test
/// does not depend on canvas finder ambiguity.
Future<void> _drawStroke(WidgetTester tester) async {
  final gesture = await tester.startGesture(const Offset(120, 300));
  await gesture.moveTo(const Offset(240, 320));
  await gesture.up();
  await tester.pumpAndSettle();
}

/// Waits (with real async) until [isDone] reports the terminal UI state,
/// pumping frames so the rasterization and fake gateway futures resolve.
Future<void> _waitUntil(
  WidgetTester tester,
  bool Function() isDone,
) async {
  await tester.runAsync(() async {
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (isDone()) return;
    }
  });
}

void main() {
  group('Signature Maker', () {
    testWidgets('Enables saving only after ink, Undo and Clear work',
        (tester) async {
      final files = FakeFileGateway();
      final images = FakeImageToolsGateway();

      await tester.pumpWidget(
          _app(files, images, const SignatureMakerScreen()));

      expect(find.text('Draw a signature first'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );

      await _drawStroke(tester);
      expect(find.text('Save PNG'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.text('Draw a signature first'), findsOneWidget);

      await _drawStroke(tester);
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();
      expect(find.text('Draw a signature first'), findsOneWidget);
    });

    testWidgets('Saves the drawn signature as a PNG', (tester) async {
      final files = FakeFileGateway();
      final images = FakeImageToolsGateway();

      await tester.pumpWidget(
          _app(files, images, const SignatureMakerScreen()));
      await _drawStroke(tester);

      // Rasterizing the RepaintBoundary needs real async work; bounded
      // pumps only, since the saving spinner never settles.
      await tester.tap(find.text('Save PNG'));
      await _waitUntil(
        tester,
        () => find.text('Signature saved').evaluate().isNotEmpty,
      );

      expect(images.writeImageBytesCalls, 1);
      expect(images.lastWrittenBytes, isNotNull);
      expect(images.lastWrittenBytes!.isNotEmpty, isTrue);
      expect(files.createRequests, ['signature.png']);
      expect(find.text('Signature saved'), findsOneWidget);
    });

    testWidgets('Surfaces write failures and returns to the canvas',
        (tester) async {
      final files = FakeFileGateway();
      final images = FakeImageToolsGateway()
        ..writeBytesError = const BridgeException('io_error', 'disk full');

      await tester.pumpWidget(
          _app(files, images, const SignatureMakerScreen()));
      await _drawStroke(tester);

      await tester.tap(find.text('Save PNG'));
      await _waitUntil(
        tester,
        () => find
            .text('Something went wrong while reading or writing files.')
            .evaluate()
            .isNotEmpty,
      );

      expect(
        find.text('Something went wrong while reading or writing files.'),
        findsOneWidget,
      );
      expect(find.text('Save PNG'), findsOneWidget);
    });
  });

  group('Passport Photo', () {
    testWidgets('Builds a sheet with the chosen copy count', (tester) async {
      final files = FakeFileGateway()..nextOpen = [_photo];
      final images = FakeImageToolsGateway();

      await tester.pumpWidget(
          _app(files, images, const PassportPhotoScreen()));
      await tester.tap(find.text('Choose photo'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save print sheet'));
      await tester.pump();
      await images.finishRunningTask();
      await tester.pumpAndSettle();

      expect(images.passportSheetCalls, 1);
      expect(images.lastPassportCopies, 3);
      expect(files.createRequests, ['passport-sheet.jpg']);
      expect(find.text('Sheet ready'), findsOneWidget);
    });

    testWidgets('Shows the native error when the sheet fails',
        (tester) async {
      final files = FakeFileGateway()..nextOpen = [_photo];
      final images = FakeImageToolsGateway()
        ..nextTaskError =
            const BridgeException('invalid_input', 'Image could not be decoded');

      await tester.pumpWidget(
          _app(files, images, const PassportPhotoScreen()));
      await tester.tap(find.text('Choose photo'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save print sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Image could not be decoded'), findsOneWidget);
      expect(find.text('Save print sheet'), findsOneWidget);
    });
  });
}
