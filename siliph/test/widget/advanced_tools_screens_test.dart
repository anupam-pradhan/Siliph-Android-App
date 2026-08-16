/// Widget tests for the Batch D–G workflows: PDF Reader, scanners,
/// QR Scanner, OCR trio, Sign/Annotate/Redact PDF (sections 10, 12, 50).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siliph/app/theme/siliph_theme.dart';
import 'package:siliph/domain/models/file_item.dart';
import 'package:siliph/domain/providers.dart';
import 'package:siliph/features/annotate/annotate_pdf_screen.dart';
import 'package:siliph/features/ocr/ocr_image_screen.dart';
import 'package:siliph/features/ocr/ocr_pdf_screen.dart';
import 'package:siliph/features/ocr/searchable_pdf_screen.dart';
import 'package:siliph/features/qr/qr_scan_screen.dart';
import 'package:siliph/features/reader/pdf_reader_screen.dart';
import 'package:siliph/features/scan/scan_capture_screen.dart';
import 'package:siliph/features/security/redact_pdf_screen.dart';
import 'package:siliph/features/signature/sign_pdf_screen.dart';
import 'package:siliph/generated/siliph_bridge.g.dart';

import 'fake_gateways.dart';

const _pdfFile = FileItem(
  uri: 'content://test/doc.pdf',
  displayName: 'doc.pdf',
  sizeBytes: 10000,
);

const _photoFile = FileItem(
  uri: 'content://test/photo.jpg',
  displayName: 'photo.jpg',
  sizeBytes: 2048,
);

/// A real 1x1 transparent PNG so Image.memory / codec decoding succeed
/// inside widget tests.
final Uint8List _tinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ'
  'AAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

/// Pumps until [isDone] with real async turns so image codec callbacks
/// (which do not fire while only pumping frames) can resolve.
Future<void> _waitUntil(
  WidgetTester tester,
  bool Function() isDone,
) async {
  await tester.runAsync(() async {
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      if (isDone()) return;
    }
  });
}

void main() {
  group('PDF Reader', () {
    testWidgets('Renders the first page and navigates forward',
        (tester) async {
      final files = FakeFileGateway()..nextOpen = [_pdfFile];
      final pdfs = FakePdfGateway()
        ..nextRenderedPage = _tinyPng
        ..inspectPageCount = 3;

      await tester.pumpWidget(ProviderScope(
        overrides: [
          fileGatewayProvider.overrideWithValue(files),
          pdfGatewayProvider.overrideWithValue(pdfs),
        ],
        child: MaterialApp(
            theme: SiliphTheme.build(), home: const PdfReaderScreen()),
      ));

      await tester.tap(find.text('Choose PDF'));
      await tester.pump();
      await tester.pump();
      await pdfs.finishRunningTask();
      await _waitUntil(tester, () => find.text('Page 1 of 3').evaluate().isNotEmpty);
      expect(pdfs.lastRenderedPageIndex, 0);

      await tester.tap(find.byTooltip('Next page'));
      await tester.pump();
      await tester.pump();
      await pdfs.finishRunningTask();
      await _waitUntil(tester, () => find.text('Page 2 of 3').evaluate().isNotEmpty);
      expect(pdfs.lastRenderedPageIndex, 1);
      expect(pdfs.renderPageCalls, 2);
    });
  });

  group('QR Scanner', () {
    testWidgets('Decodes a picked image and shows the value', (tester) async {
      final files = FakeFileGateway()..nextPickedImages = [_photoFile];
      final tools = FakeFileToolsGateway()
        ..nextBarcode =
            BarcodeResult(rawValue: 'https://siliph.app', format: 'qr');

      await tester.pumpWidget(ProviderScope(
        overrides: [
          fileGatewayProvider.overrideWithValue(files),
          fileToolsGatewayProvider.overrideWithValue(tools),
        ],
        child: MaterialApp(theme: SiliphTheme.build(), home: const QrScanScreen()),
      ));

      await tester.tap(find.text('Choose image'));
      await tester.pump();
      await tester.pump();
      await tools.finishRunningTask();
      await tester.pump();

      expect(find.text('Code found'), findsOneWidget);
      expect(find.text('https://siliph.app'), findsOneWidget);
      expect(tools.scanBarcodeCalls, 1);
    });
  });

  group('Document Scanner', () {
    testWidgets('Captures pages and builds a PDF', (tester) async {
      final files = FakeFileGateway()..nextPhoto = _photoFile;
      final pdfs = FakePdfGateway();

      await tester.pumpWidget(ProviderScope(
        overrides: [
          fileGatewayProvider.overrideWithValue(files),
          pdfGatewayProvider.overrideWithValue(pdfs),
        ],
        child: MaterialApp(
            theme: SiliphTheme.build(),
            home: const ScanCaptureScreen(mode: ScanMode.document)),
      ));

      // Save is disabled with zero pages.
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(
                FilledButton, 'Capture at least one page'))
            .onPressed,
        isNull,
      );

      await tester.tap(find.text('Scan page'));
      await tester.pump();
      await tester.pump();
      expect(find.text('photo.jpg'), findsOneWidget);

      await tester.tap(find.text('Create PDF'));
      await tester.pump();
      await tester.pump();
      await pdfs.finishRunningTask();
      await tester.pump();

      expect(find.text('Scan saved'), findsOneWidget);
      expect(pdfs.imagesToPdfCalls, 1);
      expect(files.createRequests.single, endsWith('.pdf'));
    });
  });

  group('OCR image', () {
    testWidgets('Shows recognized blocks and supports copy-all',
        (tester) async {
      final files = FakeFileGateway()..nextPickedImages = [_photoFile];
      final ocr = FakeOcrGateway()
        ..nextBlocks = [
          OcrBlock(
            text: 'Hello world',
            pageIndex: 0,
            left: 0.1,
            top: 0.1,
            right: 0.9,
            bottom: 0.2,
          ),
        ];

      await tester.pumpWidget(ProviderScope(
        overrides: [
          fileGatewayProvider.overrideWithValue(files),
          ocrGatewayProvider.overrideWithValue(ocr),
        ],
        child: MaterialApp(
            theme: SiliphTheme.build(), home: const OcrImageScreen()),
      ));

      await tester.tap(find.text('Choose image'));
      await tester.pump();
      await tester.pump();
      await ocr.finishRunningTask();
      await tester.pump();

      expect(find.text('Hello world'), findsOneWidget);
      expect(find.text('Copy all'), findsOneWidget);
      expect(ocr.recognizeImageCalls, 1);
    });
  });

  group('OCR PDF', () {
    testWidgets('Groups recognized text by page', (tester) async {
      final files = FakeFileGateway()..nextOpen = [_pdfFile];
      final ocr = FakeOcrGateway()
        ..nextBlocks = [
          OcrBlock(
              text: 'First page text',
              pageIndex: 0,
              left: 0,
              top: 0,
              right: 1,
              bottom: 0.1),
          OcrBlock(
              text: 'Second page text',
              pageIndex: 1,
              left: 0,
              top: 0,
              right: 1,
              bottom: 0.1),
        ];

      await tester.pumpWidget(ProviderScope(
        overrides: [
          fileGatewayProvider.overrideWithValue(files),
          ocrGatewayProvider.overrideWithValue(ocr),
        ],
        child:
            MaterialApp(theme: SiliphTheme.build(), home: const OcrPdfScreen()),
      ));

      await tester.tap(find.text('Choose PDF'));
      await tester.pump();
      await tester.pump();
      await ocr.finishRunningTask();
      await tester.pump();

      expect(find.text('Found text on 2 pages'), findsOneWidget);
      expect(find.text('First page text'), findsOneWidget);
      expect(find.text('Second page text'), findsOneWidget);
      expect(ocr.recognizePdfCalls, 1);
    });
  });

  group('Searchable PDF', () {
    testWidgets('Rebuilds the PDF through the OCR engine', (tester) async {
      final files = FakeFileGateway()..nextOpen = [_pdfFile];
      final ocr = FakeOcrGateway();

      await tester.pumpWidget(ProviderScope(
        overrides: [
          fileGatewayProvider.overrideWithValue(files),
          ocrGatewayProvider.overrideWithValue(ocr),
        ],
        child: MaterialApp(
            theme: SiliphTheme.build(), home: const SearchablePdfScreen()),
      ));

      await tester.tap(find.text('Choose PDF'));
      await tester.pump();
      await tester.pump();
      await ocr.finishRunningTask();
      await tester.pump();

      expect(find.text('Searchable copy saved'), findsOneWidget);
      expect(ocr.searchablePdfCalls, 1);
      expect(files.createRequests.single, 'doc-searchable.pdf');
    });
  });

  group('Sign PDF', () {
    testWidgets('Stamps the picked signature image', (tester) async {
      final files = FakeFileGateway()
        ..nextOpen = [_pdfFile]
        ..nextPickedImages = [_photoFile];
      final pdfs = FakePdfGateway()..inspectPageCount = 2;

      await tester.pumpWidget(ProviderScope(
        overrides: [
          fileGatewayProvider.overrideWithValue(files),
          pdfGatewayProvider.overrideWithValue(pdfs),
        ],
        child:
            MaterialApp(theme: SiliphTheme.build(), home: const SignPdfScreen()),
      ));

      await tester.tap(find.text('Choose PDF'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Tap to choose a signature image'), findsOneWidget);

      await tester.tap(find.text('Tap to choose a signature image'));
      await tester.pump();
      await tester.pump();
      expect(find.text('photo.jpg'), findsOneWidget);

      final signButton = find.widgetWithText(FilledButton, 'Sign PDF');
      await tester.ensureVisible(signButton);
      await tester.pump();
      await tester.tap(signButton);
      await tester.pump();
      await tester.pump();
      await pdfs.finishRunningTask();
      await tester.pump();

      expect(find.text('Signature added'), findsOneWidget);
      expect(pdfs.stampImageCalls, 1);
      expect(files.createRequests.single, 'doc-signed.pdf');
    });
  });

  group('Annotate PDF', () {
    testWidgets('Saves a drawn stroke into the content stream',
        (tester) async {
      final files = FakeFileGateway()..nextOpen = [_pdfFile];
      final pdfs = FakePdfGateway()..nextRenderedPage = _tinyPng;

      await tester.pumpWidget(ProviderScope(
        overrides: [
          fileGatewayProvider.overrideWithValue(files),
          pdfGatewayProvider.overrideWithValue(pdfs),
        ],
        child: MaterialApp(
            theme: SiliphTheme.build(), home: const AnnotatePdfScreen()),
      ));

      await tester.tap(find.text('Choose PDF'));
      await tester.pump();
      await tester.pump();
      await pdfs.finishRunningTask(); // rendered page
      await _waitUntil(
          tester, () => find.byType(Image).evaluate().isNotEmpty);

      // Save is blocked until something is drawn.
      expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Draw or mark up the page first'))
            .onPressed,
        isNull,
      );

      final annotateCenter = tester.getCenter(find.byType(Image).last);
      final gesture =
          await tester.startGesture(annotateCenter - const Offset(40, 20));
      await gesture.moveTo(annotateCenter + const Offset(40, 20));
      await gesture.up();
      await tester.pump();

      await tester.tap(find.text('Save annotations'));
      await tester.pump();
      await tester.pump();
      await pdfs.finishRunningTask();
      await tester.pump();

      expect(find.text('Annotations saved'), findsOneWidget);
      expect(pdfs.annotateCalls, 1);
      expect(pdfs.lastStrokes, hasLength(1));
      expect(pdfs.lastRects, isEmpty);
    });
  });

  group('Redact PDF', () {
    testWidgets('Confirms then burns in a marked region', (tester) async {
      final files = FakeFileGateway()..nextOpen = [_pdfFile];
      final pdfs = FakePdfGateway()..nextRenderedPage = _tinyPng;

      await tester.pumpWidget(ProviderScope(
        overrides: [
          fileGatewayProvider.overrideWithValue(files),
          pdfGatewayProvider.overrideWithValue(pdfs),
        ],
        child: MaterialApp(
            theme: SiliphTheme.build(), home: const RedactPdfScreen()),
      ));

      await tester.tap(find.text('Choose PDF'));
      await tester.pump();
      await tester.pump();
      await pdfs.finishRunningTask(); // rendered page
      await _waitUntil(
          tester, () => find.byType(Image).evaluate().isNotEmpty);

      final redactCenter = tester.getCenter(find.byType(Image).last);
      final gesture =
          await tester.startGesture(redactCenter - const Offset(40, 25));
      await gesture.moveTo(redactCenter + const Offset(40, 25));
      await gesture.up();
      await tester.pump();
      expect(find.textContaining('1 region marked'), findsOneWidget);

      await tester.tap(find.text('Redact permanently'));
      await tester.pump();
      await tester.tap(find.text('Redact'));
      await tester.pump();
      await tester.pump();
      await pdfs.finishRunningTask();
      await tester.pump();

      expect(find.text('Redaction complete'), findsOneWidget);
      expect(pdfs.redactCalls, 1);
      expect(pdfs.lastRedactionMarks, hasLength(1));
      expect(pdfs.lastRedactionMarks!.single.pageIndex, 0);
      expect(files.createRequests.single, 'doc-redacted.pdf');
    });
  });
}
