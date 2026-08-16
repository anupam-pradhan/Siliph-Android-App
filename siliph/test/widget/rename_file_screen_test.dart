/// Widget tests for the Rename File workflow (sections 34, 50).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siliph/app/theme/siliph_theme.dart';
import 'package:siliph/domain/models/file_item.dart';
import 'package:siliph/domain/providers.dart';
import 'package:siliph/domain/services/native_bridge.dart';
import 'package:siliph/features/files/rename_file_screen.dart';

import 'fake_gateways.dart';

const _file = FileItem(
  uri: 'content://test/report.pdf',
  displayName: 'Report.PDF',
  mimeType: 'application/pdf',
  sizeBytes: 2048,
);

Widget _app({required FakeFileGateway files}) {
  return ProviderScope(
    overrides: [
      fileGatewayProvider.overrideWithValue(files),
      pdfGatewayProvider.overrideWithValue(FakePdfGateway()),
    ],
    child: MaterialApp(
      theme: SiliphTheme.build(),
      home: const RenameFileScreen(),
    ),
  );
}

void main() {
  testWidgets('Picked file pre-fills the base name and keeps the extension',
      (tester) async {
    final files = FakeFileGateway()..nextOpen = [_file];

    await tester.pumpWidget(_app(files: files));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Choose file'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Report.PDF'), findsWidgets);
    expect(find.widgetWithText(TextField, 'New name'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'Report');
    expect(field.decoration!.suffixText, '.PDF');
    // Unchanged name: action disabled with guidance.
    expect(find.text('The name is unchanged.'), findsOneWidget);
    final rename = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(rename.onPressed, isNull);
  });

  testWidgets('Valid rename succeeds and shows the new name', (tester) async {
    final files = FakeFileGateway()..nextOpen = [_file];

    await tester.pumpWidget(_app(files: files));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Choose file'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Final');
    await tester.pumpAndSettle();

    expect(find.text('Will be saved as "Final.PDF".'), findsOneWidget);

    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();

    expect(files.renameRequests.single, (_file.uri, 'Final.PDF'));
    expect(find.text('Renamed'), findsOneWidget);
    expect(find.textContaining('"Final.PDF"'), findsOneWidget);
  });

  testWidgets('Invalid characters block the rename', (tester) async {
    final files = FakeFileGateway()..nextOpen = [_file];

    await tester.pumpWidget(_app(files: files));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Choose file'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'bad/name');
    await tester.pumpAndSettle();

    expect(find.text('File names cannot contain slashes.'), findsOneWidget);
    final rename = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(rename.onPressed, isNull);
    expect(files.renameRequests, isEmpty);
  });

  testWidgets('Provider refusal surfaces the typed error copy',
      (tester) async {
    final files = FakeFileGateway()
      ..nextOpen = [_file]
      ..renameError = const BridgeException(
        'not_supported',
        'This file cannot be renamed from Siliph',
      );

    await tester.pumpWidget(_app(files: files));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Choose file'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'NewName');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();

    expect(
      find.text('This file cannot be renamed from Siliph'),
      findsOneWidget,
    );
    // Still on the configuration step, able to retry.
    expect(find.text('Rename'), findsOneWidget);
  });
}
