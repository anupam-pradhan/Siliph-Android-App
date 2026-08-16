/// Widget tests for the Split PDF workflow (sections 50, 5).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siliph/app/theme/siliph_theme.dart';
import 'package:siliph/domain/models/file_item.dart';
import 'package:siliph/domain/providers.dart';
import 'package:siliph/features/split/split_pdf_screen.dart';

import 'fake_gateways.dart';

const _pdf = FileItem(
  uri: 'content://test/doc.pdf',
  displayName: 'doc.pdf',
  sizeBytes: 1024,
);

Widget _app({required FakeFileGateway files, required FakePdfGateway pdfs}) {
  return ProviderScope(
    overrides: [
      fileGatewayProvider.overrideWithValue(files),
      pdfGatewayProvider.overrideWithValue(pdfs),
    ],
    child: MaterialApp(
      theme: SiliphTheme.build(),
      home: const SplitPdfScreen(),
    ),
  );
}

Future<void> _openPdf(
  WidgetTester tester, {
  required FakeFileGateway files,
  required FakePdfGateway pdfs,
}) async {
  await tester.pumpWidget(_app(files: files, pdfs: pdfs));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Choose PDF'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Range mode extracts one part', (tester) async {
    final files = FakeFileGateway()..nextOpen = [_pdf];
    final pdfs = FakePdfGateway()..inspectPageCount = 6;

    await _openPdf(tester, files: files, pdfs: pdfs);

    expect(find.textContaining('6 pages'), findsOneWidget);

    // Default range is 1-6; narrow it to 2-4.
    await tester.enterText(
      find.widgetWithText(TextField, 'First page'),
      '2',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Last page'),
      '4',
    );
    await tester.pumpAndSettle();

    expect(find.text('Extracts pages 2-4 of 6 into one new PDF.'), findsOneWidget);

    await tester.tap(find.textContaining('Split pages 2-4'));
    await tester.pumpAndSettle();

    expect(pdfs.rearrangeCalls.single, [1, 2, 3]);
    expect(files.createRequests.single, 'doc-output.pdf');

    await pdfs.finishRunningTask();
    await tester.pumpAndSettle();

    expect(find.text('Split complete'), findsOneWidget);
  });

  testWidgets('Every-N mode saves one file per part', (tester) async {
    final files = FakeFileGateway()..nextOpen = [_pdf];
    final pdfs = FakePdfGateway()..inspectPageCount = 5;

    await _openPdf(tester, files: files, pdfs: pdfs);

    await tester.tap(find.text('Every N pages'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Pages per part'),
      '2',
    );
    await tester.pumpAndSettle();

    expect(find.text('Creates 3 parts (1-2, 3-4, 5).'), findsOneWidget);

    await tester.tap(find.text('Split into 3 parts'));
    await tester.pumpAndSettle();

    // Part 1 running.
    expect(pdfs.rearrangeCalls.length, 1);
    expect(pdfs.rearrangeCalls.last, [0, 1]);
    await pdfs.finishRunningTask();
    await tester.pumpAndSettle();

    // Part 2 running.
    expect(pdfs.rearrangeCalls.length, 2);
    expect(pdfs.rearrangeCalls.last, [2, 3]);
    await pdfs.finishRunningTask();
    await tester.pumpAndSettle();

    // Part 3 running.
    expect(pdfs.rearrangeCalls.length, 3);
    expect(pdfs.rearrangeCalls.last, [4]);
    await pdfs.finishRunningTask();
    await tester.pumpAndSettle();

    expect(find.text('Saved 3 parts'), findsOneWidget);
    expect(
      files.createRequests,
      ['doc-part-1-of-3.pdf', 'doc-part-2-of-3.pdf', 'doc-part-3-of-3.pdf'],
    );
  });

  testWidgets('Cancelling the first save dialog keeps the configuration',
      (tester) async {
    final files = FakeFileGateway()
      ..nextOpen = [_pdf]
      ..nextCreate = null;
    final pdfs = FakePdfGateway()..inspectPageCount = 4;

    await _openPdf(tester, files: files, pdfs: pdfs);

    await tester.tap(find.textContaining('Split pages 1-4'));
    await tester.pumpAndSettle();

    expect(pdfs.rearrangeCalls, isEmpty);
    expect(find.textContaining('Split pages 1-4'), findsOneWidget);
  });

  testWidgets('Invalid range disables the split action with guidance',
      (tester) async {
    final files = FakeFileGateway()..nextOpen = [_pdf];
    final pdfs = FakePdfGateway()..inspectPageCount = 4;

    await _openPdf(tester, files: files, pdfs: pdfs);

    await tester.enterText(
      find.widgetWithText(TextField, 'Last page'),
      'abc',
    );
    await tester.pumpAndSettle();

    final splitButton = tester.widget<FilledButton>(
      find.ancestor(of: find.textContaining('Split '), matching: find.byType(FilledButton)),
    );
    expect(splitButton.onPressed, isNull);
  });
}
