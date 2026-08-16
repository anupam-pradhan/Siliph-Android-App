/// Widget tests for the File Information workflow (sections 34, 50).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siliph/app/theme/siliph_theme.dart';
import 'package:siliph/domain/models/file_item.dart';
import 'package:siliph/domain/providers.dart';
import 'package:siliph/features/files/file_info_screen.dart';

import 'fake_gateways.dart';

Widget _app(FakeFileGateway files) {
  return ProviderScope(
    overrides: [
      fileGatewayProvider.overrideWithValue(files),
      pdfGatewayProvider.overrideWithValue(FakePdfGateway()),
    ],
    child: MaterialApp(
      theme: SiliphTheme.build(),
      home: const FileInfoScreen(),
    ),
  );
}

void main() {
  testWidgets('Shows honest provider facts after picking a file',
      (tester) async {
    final modified = DateTime(2026, 8, 16, 9, 5).millisecondsSinceEpoch;
    final files = FakeFileGateway()
      ..nextOpen = [
        FileItem(
          uri: 'content://com.example.provider/document/9',
          displayName: 'Report.PDF',
          mimeType: 'application/pdf',
          sizeBytes: 2048,
          lastModifiedMillis: modified,
        ),
      ];

    await tester.pumpWidget(_app(files));
    await tester.pumpAndSettle();

    expect(find.text('Inspect a file'), findsOneWidget);

    await tester.tap(find.text('Choose file'));
    await tester.pumpAndSettle();

    expect(find.text('Report.PDF'), findsOneWidget);
    expect(find.text('application/pdf'), findsOneWidget);
    expect(find.text('2026-08-16 09:05'), findsOneWidget);
    expect(find.text('com.example.provider'), findsOneWidget);
  });

  testWidgets('Missing metadata facts fall back to Unknown', (tester) async {
    final files = FakeFileGateway()
      ..nextOpen = [
        const FileItem(uri: 'file:///sdcard/x.bin', displayName: 'x.bin'),
      ];

    await tester.pumpWidget(_app(files));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Choose file'));
    await tester.pumpAndSettle();

    expect(find.text('Unknown'), findsWidgets);
  });
}
