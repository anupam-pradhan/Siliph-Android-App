/// Widget tests for the Copy / Move File workflows (sections 34, 50).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siliph/app/theme/siliph_theme.dart';
import 'package:siliph/domain/models/file_item.dart';
import 'package:siliph/domain/providers.dart';
import 'package:siliph/domain/services/native_bridge.dart';
import 'package:siliph/features/files/copy_move_screen.dart';

import 'fake_gateways.dart';

const _file = FileItem(
  uri: 'content://test/report.pdf',
  displayName: 'Report.pdf',
  sizeBytes: 2048,
);

Widget _app(FakeFileGateway files, TransferMode mode) {
  return ProviderScope(
    overrides: [
      fileGatewayProvider.overrideWithValue(files),
      pdfGatewayProvider.overrideWithValue(FakePdfGateway()),
    ],
    child: MaterialApp(
      theme: SiliphTheme.build(),
      home: CopyMoveScreen(mode: mode),
    ),
  );
}

Future<void> _pickFile(WidgetTester tester) async {
  await tester.tap(find.text('Choose file'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Copy needs a destination folder, then creates the copy',
      (tester) async {
    final files = FakeFileGateway()..nextOpen = [_file];

    await tester.pumpWidget(_app(files, TransferMode.copy));
    await tester.pumpAndSettle();
    await _pickFile(tester);

    // Without a destination, the CTA is guidance, not an action.
    expect(find.text('Choose a destination folder'), findsOneWidget);
    final cta = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(cta.onPressed, isNull);

    await tester.tap(find.text('Tap to choose a folder'));
    await tester.pumpAndSettle();

    expect(files.pickFolderCalls, 1);
    expect(find.text('Destination'), findsOneWidget);

    await tester.tap(find.text('Copy here'));
    await tester.pumpAndSettle();

    expect(files.copyCalls.single, (_file.uri, files.nextFolder));
    expect(find.text('Copied'), findsOneWidget);
    expect(find.textContaining('"Report.pdf" was created.'), findsOneWidget);
  });

  testWidgets('Move relocates the file into the picked folder',
      (tester) async {
    final files = FakeFileGateway()..nextOpen = [_file];

    await tester.pumpWidget(_app(files, TransferMode.move));
    await tester.pumpAndSettle();
    await _pickFile(tester);

    await tester.tap(find.text('Tap to choose a folder'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Move here'));
    await tester.pumpAndSettle();

    expect(files.moveCalls.single, (_file.uri, files.nextFolder));
    expect(files.copyCalls, isEmpty);
    expect(find.text('Moved'), findsOneWidget);
  });

  testWidgets('Provider refusal surfaces the honest guidance', (tester) async {
    final files = FakeFileGateway()
      ..nextOpen = [_file]
      ..copyError = const BridgeException(
        'not_supported',
        'This provider cannot copy the file from Siliph',
      );

    await tester.pumpWidget(_app(files, TransferMode.copy));
    await tester.pumpAndSettle();
    await _pickFile(tester);

    await tester.tap(find.text('Tap to choose a folder'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Copy here'));
    await tester.pumpAndSettle();

    expect(
      find.text('This provider cannot copy the file from Siliph'),
      findsOneWidget,
    );
    // Still on the ready step, able to retry.
    expect(find.text('Copy here'), findsOneWidget);
  });
}
