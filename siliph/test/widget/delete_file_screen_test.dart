/// Widget tests for the Delete File workflow (sections 34, 50).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siliph/app/theme/siliph_theme.dart';
import 'package:siliph/domain/models/file_item.dart';
import 'package:siliph/domain/providers.dart';
import 'package:siliph/domain/services/native_bridge.dart';
import 'package:siliph/features/files/delete_file_screen.dart';

import 'fake_gateways.dart';

const _file = FileItem(
  uri: 'content://test/report.pdf',
  displayName: 'Report.pdf',
  sizeBytes: 2048,
);

Widget _app(FakeFileGateway files) {
  return ProviderScope(
    overrides: [
      fileGatewayProvider.overrideWithValue(files),
      pdfGatewayProvider.overrideWithValue(FakePdfGateway()),
    ],
    child: MaterialApp(
      theme: SiliphTheme.build(),
      home: const DeleteFileScreen(),
    ),
  );
}

Future<void> _pickFile(WidgetTester tester) async {
  await tester.tap(find.text('Choose file'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Deleting requires explicit dialog confirmation',
      (tester) async {
    final files = FakeFileGateway()..nextOpen = [_file];

    await tester.pumpWidget(_app(files));
    await tester.pumpAndSettle();
    await _pickFile(tester);

    await tester.tap(find.text('Delete file'));
    await tester.pumpAndSettle();

    // The confirmation dialog is up; nothing deleted yet.
    expect(find.text('Delete this file?'), findsOneWidget);
    expect(files.deleteRequests, isEmpty);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(files.deleteRequests.single, _file.uri);
    expect(find.text('Deleted'), findsOneWidget);
    expect(find.textContaining('"Report.pdf" was deleted.'), findsOneWidget);
  });

  testWidgets('Cancelling the dialog never deletes', (tester) async {
    final files = FakeFileGateway()..nextOpen = [_file];

    await tester.pumpWidget(_app(files));
    await tester.pumpAndSettle();
    await _pickFile(tester);

    await tester.tap(find.text('Delete file'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(files.deleteRequests, isEmpty);
    // Back on the confirmation step, file still present.
    expect(find.text('Delete file'), findsOneWidget);
  });

  testWidgets('Provider refusal and bridge errors stay honest',
      (tester) async {
    final files = FakeFileGateway()
      ..nextOpen = [_file]
      ..deleteError = const BridgeException('io_error', 'Delete failed');

    await tester.pumpWidget(_app(files));
    await tester.pumpAndSettle();
    await _pickFile(tester);

    await tester.tap(find.text('Delete file'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(
      find.text('Something went wrong while reading or writing files.'),
      findsOneWidget,
    );
    // Still able to retry from the confirmation step.
    expect(find.text('Delete file'), findsOneWidget);
  });
}
