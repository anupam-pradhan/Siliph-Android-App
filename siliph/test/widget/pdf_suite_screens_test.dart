/// Widget tests for the PDF suite workflows: compress, watermark,
/// protect/unlock, metadata, images->pdf, pdf->images (sections 10, 12,
/// 14, 15, 50).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siliph/app/theme/siliph_theme.dart';
import 'package:siliph/domain/models/file_item.dart';
import 'package:siliph/domain/providers.dart';
import 'package:siliph/domain/services/native_bridge.dart';
import 'package:siliph/features/compress/compress_pdf_screen.dart';
import 'package:siliph/features/convert/images_to_pdf_screen.dart';
import 'package:siliph/features/convert/pdf_to_images_screen.dart';
import 'package:siliph/features/metadata/pdf_metadata_screen.dart';
import 'package:siliph/features/security/password_security_screen.dart';
import 'package:siliph/features/watermark/watermark_pdf_screen.dart';
import 'package:siliph/generated/siliph_bridge.g.dart';

import 'fake_gateways.dart';

const _pdf = FileItem(
  uri: 'content://test/report.pdf',
  displayName: 'Report.pdf',
  sizeBytes: 4096,
);

const _imageA = FileItem(uri: 'content://test/a.jpg', displayName: 'a.jpg');
const _imageB = FileItem(uri: 'content://test/b.png', displayName: 'b.png');

Widget _app(FakeFileGateway files, FakePdfGateway pdfs, Widget home) {
  return ProviderScope(
    overrides: [
      fileGatewayProvider.overrideWithValue(files),
      pdfGatewayProvider.overrideWithValue(pdfs),
    ],
    child: MaterialApp(theme: SiliphTheme.build(), home: home),
  );
}

Future<void> _tapAndSettle(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  group('Compress PDF', () {
    testWidgets('Compresses at the chosen level and reports honestly',
        (tester) async {
      final files = FakeFileGateway()..nextOpen = [_pdf];
      final pdfs = FakePdfGateway();

      await tester.pumpWidget(
          _app(files, pdfs, const CompressPdfScreen()));
      await _tapAndSettle(tester, 'Choose PDF');

      // Honesty copy about rasterization is visible before running.
      expect(find.textContaining('not be'), findsOneWidget);

      await tester.tap(find.text('High'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save compressed PDF'));
      await tester.pump();
      await pdfs.finishRunningTask();
      await tester.pumpAndSettle();

      expect(pdfs.compressCalls, 1);
      expect(pdfs.lastCompressLevel, 2);
      expect(find.text('Compressed'), findsOneWidget);
    });
  });

  group('Watermark PDF', () {
    testWidgets('Stamps the default text diagonally', (tester) async {
      final files = FakeFileGateway()..nextOpen = [_pdf];
      final pdfs = FakePdfGateway();

      await tester.pumpWidget(
          _app(files, pdfs, const WatermarkPdfScreen()));
      await _tapAndSettle(tester, 'Choose PDF');

      await _tapAndSettle(tester, 'Add watermark');
      await tester.pump();
      await pdfs.finishRunningTask();
      await tester.pumpAndSettle();

      expect(pdfs.watermarkCalls, 1);
      expect(pdfs.lastWatermarkText, 'CONFIDENTIAL');
      expect(pdfs.lastWatermarkPosition, 'diagonal');
      expect(find.text('Watermarked'), findsOneWidget);
    });

    testWidgets('Empty text disables the action', (tester) async {
      final files = FakeFileGateway()..nextOpen = [_pdf];
      final pdfs = FakePdfGateway();

      await tester.pumpWidget(
          _app(files, pdfs, const WatermarkPdfScreen()));
      await _tapAndSettle(tester, 'Choose PDF');

      await tester.enterText(find.byType(TextField), '   ');
      await tester.pumpAndSettle();

      expect(find.text('Enter watermark text'), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
      expect(pdfs.watermarkCalls, 0);
    });
  });

  group('Protect PDF', () {
    testWidgets('Matching passwords encrypt a saved copy', (tester) async {
      final files = FakeFileGateway()..nextOpen = [_pdf];
      final pdfs = FakePdfGateway();

      await tester.pumpWidget(_app(
        files,
        pdfs,
        const PasswordSecurityScreen(mode: SecurityMode.protect),
      ));
      await _tapAndSettle(tester, 'Choose PDF');

      await tester.enterText(find.byType(TextField).at(0), 'secret1');
      await tester.enterText(find.byType(TextField).at(1), 'secret1');
      await tester.pumpAndSettle();

      await _tapAndSettle(tester, 'Save protected copy');
      await tester.pump();
      await pdfs.finishRunningTask();
      await tester.pumpAndSettle();

      expect(pdfs.protectCalls, 1);
      expect(pdfs.lastProtectPassword, 'secret1');
      expect(find.text('Protected'), findsOneWidget);
      expect(find.textContaining('original is unchanged'), findsOneWidget);
    });

    testWidgets('Mismatched confirm keeps the action disabled',
        (tester) async {
      final files = FakeFileGateway()..nextOpen = [_pdf];
      final pdfs = FakePdfGateway();

      await tester.pumpWidget(_app(
        files,
        pdfs,
        const PasswordSecurityScreen(mode: SecurityMode.protect),
      ));
      await _tapAndSettle(tester, 'Choose PDF');

      await tester.enterText(find.byType(TextField).at(0), 'secret1');
      await tester.enterText(find.byType(TextField).at(1), 'other');
      await tester.pumpAndSettle();

      expect(find.text('The passwords do not match.'), findsOneWidget);
      expect(pdfs.protectCalls, 0);
    });
  });

  group('Unlock PDF', () {
    testWidgets('Refuses honestly when the PDF is not encrypted',
        (tester) async {
      final files = FakeFileGateway()..nextOpen = [_pdf];
      final pdfs = FakePdfGateway()..inspectEncrypted = false;

      await tester.pumpWidget(_app(
        files,
        pdfs,
        const PasswordSecurityScreen(mode: SecurityMode.unlock),
      ));
      await _tapAndSettle(tester, 'Choose PDF');

      expect(find.textContaining('not encrypted'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('Correct password saves an unlocked copy', (tester) async {
      final files = FakeFileGateway()..nextOpen = [_pdf];
      final pdfs = FakePdfGateway()..inspectEncrypted = true;

      await tester.pumpWidget(_app(
        files,
        pdfs,
        const PasswordSecurityScreen(mode: SecurityMode.unlock),
      ));
      await _tapAndSettle(tester, 'Choose PDF');

      await tester.enterText(find.byType(TextField), 'open-sesame');
      await tester.pumpAndSettle();

      await _tapAndSettle(tester, 'Save unlocked copy');
      await tester.pump();
      await pdfs.finishRunningTask();
      await tester.pumpAndSettle();

      expect(pdfs.unlockCalls, 1);
      expect(pdfs.lastUnlockPassword, 'open-sesame');
      expect(find.text('Unlocked'), findsOneWidget);
    });

    testWidgets('Wrong password surfaces the plain error (section 14)',
        (tester) async {
      final files = FakeFileGateway()..nextOpen = [_pdf];
      final pdfs = FakePdfGateway()
        ..inspectEncrypted = true
        ..nextTaskError =
            const BridgeException('invalid_input', 'Wrong password');

      await tester.pumpWidget(_app(
        files,
        pdfs,
        const PasswordSecurityScreen(mode: SecurityMode.unlock),
      ));
      await _tapAndSettle(tester, 'Choose PDF');

      await tester.enterText(find.byType(TextField), 'guess');
      await tester.pumpAndSettle();

      await _tapAndSettle(tester, 'Save unlocked copy');
      await tester.pumpAndSettle();

      expect(find.text('Wrong password'), findsOneWidget);
      // Still on the password step, able to retry.
      expect(find.text('Save unlocked copy'), findsOneWidget);
    });
  });

  group('PDF Metadata', () {
    testWidgets('Shows current fields and saves edits to a copy',
        (tester) async {
      final files = FakeFileGateway()..nextOpen = [_pdf];
      final pdfs = FakePdfGateway()
        ..nextMetadata = PdfMetadata(title: 'Existing Title', author: 'Ana');

      await tester.pumpWidget(
          _app(files, pdfs, const PdfMetadataScreen()));
      await _tapAndSettle(tester, 'Choose PDF');

      final titleField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Title'),
      );
      expect(titleField.controller!.text, 'Existing Title');

      await _tapAndSettle(tester, 'Save copy with these details');
      await tester.pump();
      await pdfs.finishRunningTask();
      await tester.pumpAndSettle();

      expect(pdfs.writeMetadataCalls, 1);
      expect(pdfs.lastRemoveAll, false);
      expect(find.text('Metadata saved'), findsOneWidget);
    });

    testWidgets('Remove all asks for confirmation, then strips',
        (tester) async {
      final files = FakeFileGateway()..nextOpen = [_pdf];
      final pdfs = FakePdfGateway();

      await tester.pumpWidget(
          _app(files, pdfs, const PdfMetadataScreen()));
      await _tapAndSettle(tester, 'Choose PDF');

      await tester.tap(find.text('Remove all metadata'));
      await tester.pumpAndSettle();
      expect(find.text('Remove all metadata?'), findsOneWidget);
      expect(pdfs.writeMetadataCalls, 0);

      await _tapAndSettle(tester, 'Remove');
      await tester.pump();
      await pdfs.finishRunningTask();
      await tester.pumpAndSettle();

      expect(pdfs.writeMetadataCalls, 1);
      expect(pdfs.lastRemoveAll, true);
      expect(find.text('Metadata removed'), findsOneWidget);
    });
  });

  group('Images to PDF', () {
    testWidgets('Picked images become pages in order', (tester) async {
      final files = FakeFileGateway()
        ..nextPickedImages = [_imageA, _imageB];
      final pdfs = FakePdfGateway();

      await tester.pumpWidget(
          _app(files, pdfs, const ImagesToPdfScreen()));
      await _tapAndSettle(tester, 'Add images');

      expect(find.text('1.'), findsOneWidget);
      expect(find.text('2.'), findsOneWidget);

      await _tapAndSettle(tester, 'Save PDF (2 pages)');
      await tester.pump();
      await pdfs.finishRunningTask();
      await tester.pumpAndSettle();

      expect(pdfs.imagesToPdfCalls, 1);
      expect(pdfs.lastImageUris, [_imageA.uri, _imageB.uri]);
      expect(find.text('PDF created'), findsOneWidget);
    });

    testWidgets('Single-image variant takes one file', (tester) async {
      final files = FakeFileGateway()
        ..nextOpen = [_imageA, _imageB];
      final pdfs = FakePdfGateway();

      await tester.pumpWidget(_app(
        files,
        pdfs,
        const ImagesToPdfScreen(single: true),
      ));
      await _tapAndSettle(tester, 'Choose image');

      expect(find.text('a.jpg'), findsOneWidget);
      expect(find.text('b.jpg'), findsNothing);

      await _tapAndSettle(tester, 'Save PDF (1 page)');
      await tester.pump();
      await pdfs.finishRunningTask();
      await tester.pumpAndSettle();

      expect(pdfs.lastImageUris, [_imageA.uri]);
      expect(find.text('PDF created'), findsOneWidget);
    });
  });

  group('PDF to Images', () {
    testWidgets('Renders every page into the chosen folder', (tester) async {
      final files = FakeFileGateway()..nextOpen = [_pdf];
      final pdfs = FakePdfGateway()
        ..nextFiles = ['content://test/tree/page-1.png', 'content://test/tree/page-2.png'];

      await tester.pumpWidget(
          _app(files, pdfs, const PdfToImagesScreen()));
      await _tapAndSettle(tester, 'Choose PDF');

      // No folder yet: guidance, not an action.
      expect(find.text('Choose a destination folder'), findsOneWidget);

      await _tapAndSettle(tester, 'Tap to choose a folder');
      await _tapAndSettle(tester, 'Render pages');
      await tester.pump();
      await pdfs.finishRunningTask();
      await tester.pumpAndSettle();

      expect(pdfs.pdfToImagesCalls, 1);
      expect(pdfs.lastDpi, 150);
      expect(pdfs.lastFolderUri, files.nextFolder);
      expect(find.textContaining('2 images saved'), findsOneWidget);
    });
  });
}
