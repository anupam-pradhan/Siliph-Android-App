/// Widget tests for the Merge PDF workflow (sections 50, 5).
///
/// Uses fake gateways so no platform channels are touched; the screen is
/// exercised end to end: pick -> order -> merge -> success.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siliph/app/theme/siliph_theme.dart';
import 'package:siliph/domain/models/file_item.dart';
import 'package:siliph/domain/providers.dart';
import 'package:siliph/domain/services/native_bridge.dart';
import 'package:siliph/features/merge/merge_pdf_screen.dart';
import 'package:siliph/generated/siliph_bridge.g.dart';

const _pdfA = FileItem(uri: 'content://test/a.pdf', displayName: 'a.pdf', sizeBytes: 1024);
const _pdfB = FileItem(uri: 'content://test/b.pdf', displayName: 'b.pdf', sizeBytes: 2048);
const _output = FileItem(uri: 'content://test/out.pdf', displayName: 'merged-out.pdf');

class FakeFileGateway implements FileGateway {
  List<FileItem> nextOpen = const [];
  FileItem? nextCreate = _output;
  final openRequests = <List<String>>[];

  @override
  Future<List<FileItem>> openDocuments(List<String> mimeTypes) async {
    openRequests.add(mimeTypes);
    return nextOpen;
  }

  @override
  Future<List<FileItem>> pickImages({int maxItems = 10}) async => const [];

  @override
  Future<FileItem?> createDocument({
    required String mimeType,
    required String displayName,
  }) async =>
      nextCreate;

  @override
  Future<FileItem> rename(FileItem file, String newDisplayName) =>
      throw UnimplementedError();

  @override
  Future<bool> delete(FileItem file) => throw UnimplementedError();

  @override
  Future<String?> pickFolder() => throw UnimplementedError();

  @override
  Future<FileItem> copy(FileItem file, String targetTreeUri) =>
      throw UnimplementedError();

  @override
  Future<FileItem> move(FileItem file, String targetTreeUri) =>
      throw UnimplementedError();

  @override
  Future<void> share(FileItem file) => throw UnimplementedError();

  @override
  Future<FileItem?> takePhoto() => throw UnimplementedError();
}

class FakePdfGateway implements PdfGateway {
  final inspected = <String>[];
  List<FileItem>? lastInputs;
  FileItem? lastOutput;
  Completer<void>? mergeCompleter;
  bool cancelRequested = false;

  @override
  Future<PdfInfo> inspect(FileItem file) async {
    inspected.add(file.uri);
    return PdfInfo(uri: file.uri, pageCount: 3, encrypted: false);
  }

  @override
  TaskHandle merge({
    required List<FileItem> inputs,
    required FileItem output,
  }) {
    lastInputs = inputs;
    lastOutput = output;
    mergeCompleter = Completer<void>();
    final progress = StreamController<double>.broadcast();
    return TaskHandle(
      taskId: 'fake-task',
      progress: progress.stream,
      done: mergeCompleter!.future,
      onCancelTask: () async {
        cancelRequested = true;
        mergeCompleter!.completeError(const BridgeException('cancelled', 'x'));
      },
    );
  }

  @override
  TaskHandle rearrangePages({
    required FileItem input,
    required List<int> pageOrder,
    required FileItem output,
  }) =>
      throw UnimplementedError();

  @override
  TaskHandle rotatePages({
    required FileItem input,
    required int firstPage,
    required int lastPage,
    required int rotationDelta,
    required FileItem output,
  }) =>
      throw UnimplementedError();

  @override
  Future<PdfMetadata> readMetadata(FileItem file) =>
      throw UnimplementedError();

  @override
  TaskHandle writeMetadata({
    required FileItem input,
    required PdfMetadata metadata,
    required bool removeAll,
    required FileItem output,
  }) =>
      throw UnimplementedError();

  @override
  TaskHandle compress({
    required FileItem input,
    required int level,
    required FileItem output,
  }) =>
      throw UnimplementedError();

  @override
  TaskHandle imagesToPdf({
    required List<FileItem> images,
    required FileItem output,
  }) =>
      throw UnimplementedError();

  @override
  TaskHandle pdfToImages({
    required FileItem input,
    required int dpi,
    required String folderTreeUri,
  }) =>
      throw UnimplementedError();

  @override
  TaskHandle watermark({
    required FileItem input,
    required String text,
    required String position,
    required FileItem output,
  }) =>
      throw UnimplementedError();

  @override
  TaskHandle protect({
    required FileItem input,
    required String password,
    required FileItem output,
  }) =>
      throw UnimplementedError();

  @override
  TaskHandle unlock({
    required FileItem input,
    required String password,
    required FileItem output,
  }) =>
      throw UnimplementedError();

  @override
  TaskHandle renderPage({
    required FileItem input,
    required int pageIndex,
    required int dpi,
  }) =>
      throw UnimplementedError();

  @override
  TaskHandle stampImage({
    required FileItem input,
    required FileItem image,
    required int pageNumber,
    required double x,
    required double y,
    required double widthFraction,
    required FileItem output,
  }) =>
      throw UnimplementedError();

  @override
  TaskHandle annotate({
    required FileItem input,
    required int pageNumber,
    required List<InkStroke> strokes,
    required List<RectMark> rects,
    required FileItem output,
  }) =>
      throw UnimplementedError();

  @override
  TaskHandle redact({
    required FileItem input,
    required List<RedactionMark> marks,
    required FileItem output,
  }) =>
      throw UnimplementedError();
}

Widget _app({required FakeFileGateway files, required FakePdfGateway pdfs}) {
  return ProviderScope(
    overrides: [
      fileGatewayProvider.overrideWithValue(files),
      pdfGatewayProvider.overrideWithValue(pdfs),
    ],
    child: MaterialApp(
      theme: SiliphTheme.build(),
      home: const MergePdfScreen(),
    ),
  );
}

void main() {
  testWidgets('Empty state offers an add action', (tester) async {
    await tester.pumpWidget(_app(files: FakeFileGateway(), pdfs: FakePdfGateway()));
    await tester.pumpAndSettle();

    expect(find.text('No PDFs yet'), findsOneWidget);
    expect(find.text('Add PDFs'), findsWidgets);
    expect(find.textContaining('Merge (add 2 more)'), findsOneWidget);
  });

  testWidgets('Picked PDFs are inspected and listed', (tester) async {
    final files = FakeFileGateway()..nextOpen = [_pdfA, _pdfB];
    final pdfs = FakePdfGateway();

    await tester.pumpWidget(_app(files: files, pdfs: pdfs));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add PDFs').last);
    await tester.pumpAndSettle();

    expect(files.openRequests.single, ['application/pdf']);
    expect(pdfs.inspected, [_pdfA.uri, _pdfB.uri]);
    expect(find.text('a.pdf'), findsOneWidget);
    expect(find.text('b.pdf'), findsOneWidget);
    expect(find.textContaining('3 pages'), findsNWidgets(2));
    expect(find.textContaining('Merge 2 PDFs'), findsOneWidget);
  });

  testWidgets('Merge completes and shows the saved output', (tester) async {
    final files = FakeFileGateway()..nextOpen = [_pdfA, _pdfB];
    final pdfs = FakePdfGateway();

    await tester.pumpWidget(_app(files: files, pdfs: pdfs));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add PDFs').last);
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Merge 2 PDFs'));
    await tester.pumpAndSettle();

    // Merge is now running against the fake engine.
    expect(find.textContaining('Merging'), findsOneWidget);
    expect(pdfs.lastOutput, _output);
    expect(pdfs.lastInputs!.map((f) => f.uri), [_pdfA.uri, _pdfB.uri]);

    pdfs.mergeCompleter!.complete();
    await tester.pumpAndSettle();

    expect(find.text('Merged successfully'), findsOneWidget);
    expect(find.textContaining('merged-out.pdf'), findsOneWidget);
  });

  testWidgets('Cancelling the save dialog returns to idle', (tester) async {
    final files = FakeFileGateway()
      ..nextOpen = [_pdfA, _pdfB]
      ..nextCreate = null;
    final pdfs = FakePdfGateway();

    await tester.pumpWidget(_app(files: files, pdfs: pdfs));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add PDFs').last);
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Merge 2 PDFs'));
    await tester.pumpAndSettle();

    expect(pdfs.mergeCompleter, isNull);
    expect(find.textContaining('Merge 2 PDFs'), findsOneWidget);
  });
}
