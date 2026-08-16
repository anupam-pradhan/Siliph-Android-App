/// Widget tests for the Page Composer workflow covering all three entry
/// modes: extract, delete and reorder (sections 50, 5).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siliph/app/theme/siliph_theme.dart';
import 'package:siliph/domain/models/file_item.dart';
import 'package:siliph/domain/providers.dart';
import 'package:siliph/features/pages/page_composer_screen.dart';

import 'fake_gateways.dart';

const _pdf = FileItem(
  uri: 'content://test/doc.pdf',
  displayName: 'doc.pdf',
  sizeBytes: 1024,
);

Widget _app(
  ComposerMode mode, {
  required FakeFileGateway files,
  required FakePdfGateway pdfs,
}) {
  return ProviderScope(
    overrides: [
      fileGatewayProvider.overrideWithValue(files),
      pdfGatewayProvider.overrideWithValue(pdfs),
    ],
    child: MaterialApp(
      theme: SiliphTheme.build(),
      home: PageComposerScreen(mode: mode),
    ),
  );
}

Future<void> _openPdf(
  WidgetTester tester,
  ComposerMode mode, {
  required FakeFileGateway files,
  required FakePdfGateway pdfs,
}) async {
  await tester.pumpWidget(_app(mode, files: files, pdfs: pdfs));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Choose PDF'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Extract mode keeps only ticked pages in displayed order',
      (tester) async {
    final files = FakeFileGateway()..nextOpen = [_pdf];
    final pdfs = FakePdfGateway()..inspectPageCount = 3;

    await _openPdf(tester, ComposerMode.extract, files: files, pdfs: pdfs);

    expect(find.text('Page 1'), findsOneWidget);
    expect(find.text('Page 2'), findsOneWidget);
    expect(find.text('Page 3'), findsOneWidget);
    expect(find.textContaining('Extract selected pages (3 pages)'), findsOneWidget);

    // Untick page 2.
    await tester.tap(find.text('Page 2'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Extract selected pages (2 pages)'));
    await tester.pumpAndSettle();

    expect(pdfs.rearrangeCalls.single, [0, 2]);
    expect(files.createRequests.single, 'doc-extracted.pdf');

    await pdfs.finishRunningTask();
    await tester.pumpAndSettle();

    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('Delete mode saves the unticked complement', (tester) async {
    final files = FakeFileGateway()..nextOpen = [_pdf];
    final pdfs = FakePdfGateway()..inspectPageCount = 4;

    await _openPdf(tester, ComposerMode.delete, files: files, pdfs: pdfs);

    // Untick pages 1 and 3.
    await tester.tap(find.text('Page 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Page 3'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Save without deleted pages (2 pages)'));
    await tester.pumpAndSettle();

    expect(pdfs.rearrangeCalls.single, [1, 3]);
    expect(files.createRequests.single, 'doc-trimmed.pdf');
  });

  testWidgets('Reorder mode applies the displayed order', (tester) async {
    final files = FakeFileGateway()..nextOpen = [_pdf];
    final pdfs = FakePdfGateway()..inspectPageCount = 3;

    await _openPdf(tester, ComposerMode.reorder, files: files, pdfs: pdfs);

    // Move page 1 down once: order becomes 2, 1, 3.
    await tester.tap(find.byTooltip('Move later').first);
    await tester.pumpAndSettle();

    expect(find.text('Page 2'), findsOneWidget);

    await tester.tap(find.textContaining('Save new order (3 pages)'));
    await tester.pumpAndSettle();

    expect(pdfs.rearrangeCalls.single, [1, 0, 2]);
    expect(files.createRequests.single, 'doc-reordered.pdf');
  });

  testWidgets('Reverse flips the page order', (tester) async {
    final files = FakeFileGateway()..nextOpen = [_pdf];
    final pdfs = FakePdfGateway()..inspectPageCount = 3;

    await _openPdf(tester, ComposerMode.reorder, files: files, pdfs: pdfs);

    await tester.tap(find.text('Reverse'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Save new order (3 pages)'));
    await tester.pumpAndSettle();

    expect(pdfs.rearrangeCalls.single, [2, 1, 0]);
  });

  testWidgets('No selection disables the action', (tester) async {
    final files = FakeFileGateway()..nextOpen = [_pdf];
    final pdfs = FakePdfGateway()..inspectPageCount = 2;

    await _openPdf(tester, ComposerMode.extract, files: files, pdfs: pdfs);

    await tester.tap(find.text('Select none'));
    await tester.pumpAndSettle();

    final apply = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(apply.onPressed, isNull);
  });
}
