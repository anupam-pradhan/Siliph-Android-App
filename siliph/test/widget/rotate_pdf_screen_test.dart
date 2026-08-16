/// Widget tests for the Rotate Pages workflow (sections 50, 5).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siliph/app/theme/siliph_theme.dart';
import 'package:siliph/domain/models/file_item.dart';
import 'package:siliph/domain/providers.dart';
import 'package:siliph/features/pages/rotate_pdf_screen.dart';

import 'fake_gateways.dart';

const _pdf = FileItem(
  uri: 'content://test/in.pdf',
  displayName: 'in.pdf',
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
      home: const RotatePdfScreen(),
    ),
  );
}

void main() {
  testWidgets('Picked PDF shows its page count and defaults to all pages',
      (tester) async {
    final files = FakeFileGateway()..nextOpen = [_pdf];
    final pdfs = FakePdfGateway()..inspectPageCount = 5;

    await tester.pumpWidget(_app(files: files, pdfs: pdfs));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Choose PDF'));
    await tester.pumpAndSettle();

    expect(find.textContaining('5 pages'), findsOneWidget);
    expect(find.text('Rotates pages 1-5 clockwise by 90°.'), findsOneWidget);
  });

  testWidgets('Rotate runs with the chosen range and completes',
      (tester) async {
    final files = FakeFileGateway()..nextOpen = [_pdf];
    final pdfs = FakePdfGateway()..inspectPageCount = 5;

    await tester.pumpWidget(_app(files: files, pdfs: pdfs));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Choose PDF'));
    await tester.pumpAndSettle();

    // Rotate 180 instead of the default 90.
    await tester.tap(find.text('180°'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rotate and save'));
    await tester.pumpAndSettle();

    expect(pdfs.rotateCalls, 1);
    expect(pdfs.lastFirstPage, 1);
    expect(pdfs.lastLastPage, 5);
    expect(pdfs.lastRotationDelta, 180);
    expect(files.createRequests.single, 'in-rotated.pdf');

    await pdfs.finishRunningTask();
    await tester.pumpAndSettle();

    expect(find.text('Rotated successfully'), findsOneWidget);
  });

  testWidgets('Cancelling the save dialog returns to configuration',
      (tester) async {
    final files = FakeFileGateway()
      ..nextOpen = [_pdf]
      ..nextCreate = null;
    final pdfs = FakePdfGateway()..inspectPageCount = 5;

    await tester.pumpWidget(_app(files: files, pdfs: pdfs));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Choose PDF'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rotate and save'));
    await tester.pumpAndSettle();

    expect(pdfs.rotateCalls, 0);
    expect(find.text('Rotate and save'), findsOneWidget);
  });
}
