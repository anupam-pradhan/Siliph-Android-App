/// Widget tests for the Batch B file-tool workflows: ZIP create/extract,
/// QR generator, duplicate finder, storage analyzer (sections 10, 12, 50).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siliph/app/theme/siliph_theme.dart';
import 'package:siliph/domain/models/file_item.dart';
import 'package:siliph/domain/providers.dart';
import 'package:siliph/domain/services/native_bridge.dart';
import 'package:siliph/features/archive/zip_create_screen.dart';
import 'package:siliph/features/archive/zip_extract_screen.dart';
import 'package:siliph/features/files/duplicate_finder_screen.dart';
import 'package:siliph/features/files/storage_analyzer_screen.dart';
import 'package:siliph/features/qr/qr_generate_screen.dart';
import 'package:siliph/generated/siliph_bridge.g.dart';

import 'fake_gateways.dart';

const _fileA = FileItem(uri: 'content://test/a.txt', displayName: 'a.txt',
    sizeBytes: 1024);
const _fileB = FileItem(uri: 'content://test/b.txt', displayName: 'b.txt',
    sizeBytes: 2048);
const _zip = FileItem(uri: 'content://test/data.zip', displayName: 'data.zip',
    sizeBytes: 4096);

Widget _app(
  FakeFileGateway files,
  FakeFileToolsGateway tools,
  Widget home,
) {
  return ProviderScope(
    overrides: [
      fileGatewayProvider.overrideWithValue(files),
      fileToolsGatewayProvider.overrideWithValue(tools),
    ],
    child: MaterialApp(theme: SiliphTheme.build(), home: home),
  );
}

Future<void> _tapAndSettle(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  group('Create ZIP', () {
    testWidgets('Compresses picked files through the save dialog',
        (tester) async {
      final files = FakeFileGateway()..nextOpen = [_fileA, _fileB];
      final tools = FakeFileToolsGateway();

      await tester.pumpWidget(_app(files, tools, const ZipCreateScreen()));
      await _tapAndSettle(tester, 'Add');
      expect(find.text('a.txt'), findsOneWidget);
      expect(find.text('b.txt'), findsOneWidget);

      await tester.tap(find.text('Save ZIP (2 files)'));
      await tester.pump();
      await tools.finishRunningTask();
      await tester.pumpAndSettle();

      expect(tools.zipCreateCalls, 1);
      expect(tools.lastZipInputs, ['content://test/a.txt', 'content://test/b.txt']);
      expect(files.createRequests, ['archive.zip']);
      expect(find.text('Archive saved'), findsOneWidget);
    });

    testWidgets('Shows the error banner when archiving fails', (tester) async {
      final files = FakeFileGateway()..nextOpen = [_fileA];
      final tools = FakeFileToolsGateway()
        ..nextTaskError = const BridgeException('io_error', 'disk full');

      await tester.pumpWidget(_app(files, tools, const ZipCreateScreen()));
      await _tapAndSettle(tester, 'Add');
      await tester.tap(find.text('Save ZIP (1 file)'));
      await tester.pumpAndSettle(); // Error is delivered immediately.

      expect(find.text('Something went wrong while reading or writing files.'),
          findsOneWidget);
    });
  });

  group('Extract ZIP', () {
    testWidgets('Extracts into the picked folder and reports the count',
        (tester) async {
      final files = FakeFileGateway()..nextOpen = [_zip];
      final tools = FakeFileToolsGateway()
        ..nextFiles = ['content://test/out/one.txt', 'content://test/out/two.txt'];

      await tester.pumpWidget(_app(files, tools, const ZipExtractScreen()));
      await _tapAndSettle(tester, 'Choose ZIP');
      await _tapAndSettle(tester, 'Tap to choose a folder');

      await tester.tap(find.text('Extract'));
      await tester.pump();
      await tools.finishRunningTask();
      await tester.pumpAndSettle();

      expect(tools.zipExtractCalls, 1);
      expect(tools.lastExtractFolder, 'content://test/tree/Downloads');
      expect(find.textContaining('2 files saved into'), findsOneWidget);
    });
  });

  group('QR Generator', () {
    testWidgets('Saves a QR PNG with the chosen error correction',
        (tester) async {
      final files = FakeFileGateway();
      final tools = FakeFileToolsGateway();

      await tester.pumpWidget(_app(files, tools, const QrGenerateScreen()));
      await tester.enterText(find.byType(TextField), 'https://siliph.app');
      await tester.pumpAndSettle();
      await tester.tap(find.text('High'));
      await tester.pumpAndSettle();

      await _tapAndSettle(tester, 'Save PNG');

      expect(tools.generateQrCalls, 1);
      expect(tools.lastQrContent, 'https://siliph.app');
      expect(tools.lastQrEcLevel, 3);
      expect(files.createRequests, ['qrcode.png']);
      expect(find.text('QR code saved'), findsOneWidget);
    });

    testWidgets('Reports a failure when the encoder rejects the content',
        (tester) async {
      final files = FakeFileGateway();
      final tools = FakeFileToolsGateway()
        ..qrError =
            const BridgeException('invalid_input', 'Content too long');

      await tester.pumpWidget(_app(files, tools, const QrGenerateScreen()));
      await tester.enterText(find.byType(TextField), 'too much');
      await tester.pumpAndSettle();
      await _tapAndSettle(tester, 'Save PNG');

      expect(find.text('Content too long'), findsOneWidget);
    });
  });

  group('Duplicate Finder', () {
    testWidgets('Lists duplicate groups with reclaimable space',
        (tester) async {
      final files = FakeFileGateway();
      final tools = FakeFileToolsGateway()
        ..nextDuplicates = [
          DuplicateGroup(sizeBytes: 1048576, uris: const [
            'content://test/photo.jpg',
            'content://test/photo_copy.jpg',
          ]),
        ];

      await tester.pumpWidget(
          _app(files, tools, const DuplicateFinderScreen()));
      await _tapAndSettle(tester, 'Tap to choose a folder');
      await tester.tap(find.text('Find duplicates'));
      await tester.pump();
      await tools.finishRunningTask();
      await tester.pumpAndSettle();

      expect(tools.findDuplicatesCalls, 1);
      expect(tools.lastDuplicatesFolder, 'content://test/tree/Downloads');
      expect(find.textContaining('1 duplicate group'), findsOneWidget);
      expect(find.textContaining('1.0MB reclaimable'), findsOneWidget);
      expect(find.text('photo_copy.jpg'), findsOneWidget);
    });

    testWidgets('Celebrates when the folder has no duplicates',
        (tester) async {
      final files = FakeFileGateway();
      final tools = FakeFileToolsGateway();

      await tester.pumpWidget(
          _app(files, tools, const DuplicateFinderScreen()));
      await _tapAndSettle(tester, 'Tap to choose a folder');
      await tester.tap(find.text('Find duplicates'));
      await tester.pump();
      await tools.finishRunningTask();
      await tester.pumpAndSettle();

      expect(find.text('No duplicates found'), findsOneWidget);
    });
  });

  group('Storage Analyzer', () {
    testWidgets('Shows sorted entries with sizes and shares', (tester) async {
      final files = FakeFileGateway();
      final tools = FakeFileToolsGateway()
        ..nextStorage = [
          StorageEntry(
              name: 'Videos',
              uri: 'content://test/tree/Videos',
              sizeBytes: 3 * 1024 * 1024 * 1024,
              fileCount: 12,
              folder: true),
          StorageEntry(
              name: 'backup.zip',
              uri: 'content://test/backup.zip',
              sizeBytes: 1024 * 1024 * 1024,
              fileCount: 1,
              folder: false),
        ];

      await tester.pumpWidget(
          _app(files, tools, const StorageAnalyzerScreen()));
      await _tapAndSettle(tester, 'Tap to choose a folder');
      await tester.tap(find.text('Analyze'));
      await tester.pump();
      await tools.finishRunningTask();
      await tester.pumpAndSettle();

      expect(tools.analyzeStorageCalls, 1);
      expect(tools.lastAnalyzedFolder, 'content://test/tree/Downloads');
      expect(find.textContaining('4.0GB total'), findsOneWidget);
      expect(find.text('Videos'), findsOneWidget);
      expect(find.text('backup.zip'), findsOneWidget);
      expect(find.textContaining('75.0% of total'), findsOneWidget);
    });
  });
}
