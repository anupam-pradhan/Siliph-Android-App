/// Widget tests for the Share File workflow (sections 34, 50).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siliph/app/theme/siliph_theme.dart';
import 'package:siliph/domain/models/file_item.dart';
import 'package:siliph/domain/providers.dart';
import 'package:siliph/domain/services/native_bridge.dart';
import 'package:siliph/features/files/share_file_screen.dart';

import 'fake_gateways.dart';

const _file = FileItem(
  uri: 'content://test/report.pdf',
  displayName: 'Report.pdf',
  mimeType: 'application/pdf',
);

Widget _app(FakeFileGateway files) {
  return ProviderScope(
    overrides: [
      fileGatewayProvider.overrideWithValue(files),
      pdfGatewayProvider.overrideWithValue(FakePdfGateway()),
    ],
    child: MaterialApp(
      theme: SiliphTheme.build(),
      home: const ShareFileScreen(),
    ),
  );
}

void main() {
  testWidgets('Sharing hands the file to the system share sheet',
      (tester) async {
    final files = FakeFileGateway()..nextOpen = [_file];

    await tester.pumpWidget(_app(files));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Choose file'));
    await tester.pumpAndSettle();

    expect(find.text('Report.pdf'), findsOneWidget);
    expect(files.shareCalls, 0);

    await tester.tap(find.text('Share file'));
    await tester.pumpAndSettle();

    expect(files.shareCalls, 1);
    expect(
      find.textContaining('The share sheet was opened.'),
      findsOneWidget,
    );
  });

  testWidgets('Share failures keep the file and show guidance',
      (tester) async {
    final files = FakeFileGateway()
      ..nextOpen = [_file]
      ..shareError = const BridgeException('io_error', 'boom');

    await tester.pumpWidget(_app(files));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Choose file'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Share file'));
    await tester.pumpAndSettle();

    expect(find.text('Could not open the share sheet.'), findsOneWidget);
    expect(find.text('Share file'), findsOneWidget);
  });
}
