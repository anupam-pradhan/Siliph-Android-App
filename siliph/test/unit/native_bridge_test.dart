/// Unit tests for the native bridge Dart layer (sections 5, 213).
///
/// Exercises the event router and gateways without platform channels:
/// the router is driven exactly the way the Kotlin side drives it.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:siliph/domain/models/file_item.dart';
import 'package:siliph/domain/services/native_bridge.dart';
import 'package:siliph/generated/siliph_bridge.g.dart';

FileMeta _meta(String name, {int size = 1024}) => FileMeta(
      uri: 'content://test/$name',
      displayName: name,
      mimeType: 'application/pdf',
      sizeBytes: size,
    );

void main() {
  group('BridgeEventRouter picker results', () {
    test('open results resolve the waiting completer once', () async {
      final router = BridgeEventRouter();
      final completer = router.expectOpenResult();
      router.onOpenResult([_meta('a.pdf'), _meta('b.pdf')]);
      final files = await completer.future;
      expect(files, hasLength(2));
      // Duplicate events without a pending request are ignored safely.
      router.onOpenResult([_meta('late.pdf')]);
    });

    test('create-document cancellation resolves null', () async {
      final router = BridgeEventRouter();
      final completer = router.expectCreateDocumentResult();
      router.onCreateDocumentResult(null);
      expect(await completer.future, isNull);
    });

    test('pick-images results route to their own completer', () async {
      final router = BridgeEventRouter();
      final pick = router.expectPickImagesResult();
      final open = router.expectOpenResult();
      router.onPickImagesResult([_meta('photo.jpg')]);
      expect(await pick.future, hasLength(1));
      expect(open.isCompleted, isFalse);
    });
  });

  group('BridgeEventRouter task events', () {
    test('progress and completion flow to the registered task', () async {
      final router = BridgeEventRouter();
      final state = router.registerTask('t1');
      // toList completes when the router closes the stream on completion.
      final fractions = state.progress.stream.toList();

      router.onProgress('t1', 0.5);
      router.onComplete('t1');
      await state.done.future;

      expect(await fractions, [0.5, 1.0]);
    });

    test('errors complete the task with a typed BridgeException', () async {
      final router = BridgeEventRouter();
      final state = router.registerTask('t2');

      router.onError('t2', 'invalid_pdf', 'bad file');

      await expectLater(
        state.done.future,
        throwsA(isA<BridgeException>()
            .having((e) => e.code, 'code', 'invalid_pdf')
            .having((e) => e.userMessage, 'userMessage',
                'That file is not a readable PDF.')),
      );
    });

    test('events for unknown tasks are dropped', () {
      final router = BridgeEventRouter();
      router.onProgress('ghost', 0.1);
      router.onComplete('ghost');
      router.onError('ghost', 'io_error', 'x');
    });
  });

  group('BridgeException', () {
    test('cancellation is identifiable and user-safe', () {
      const e = BridgeException('cancelled', 'Merge cancelled');
      expect(e.isCancelled, isTrue);
      expect(e.userMessage, 'Cancelled.');
    });

    test('unknown codes fall back to generic copy', () {
      const e = BridgeException('mystery', 'raw native detail');
      expect(e.userMessage, isNot(contains('raw native detail')));
    });
  });

  group('FileItem', () {
    test('formattedSize formats units and hides unknown sizes', () {
      expect(
        FileItem(uri: 'u', displayName: 'a.pdf', sizeBytes: 512).formattedSize,
        '512B',
      );
      expect(
        FileItem(uri: 'u', displayName: 'a.pdf', sizeBytes: 2 * 1024 * 1024)
            .formattedSize,
        '2.0MB',
      );
      expect(
        FileItem(uri: 'u', displayName: 'a.pdf', sizeBytes: -1).formattedSize,
        '',
      );
    });

    test('extension is lower-cased and defensive', () {
      expect(FileItem(uri: 'u', displayName: 'A.PDF').extension, 'pdf');
      expect(FileItem(uri: 'u', displayName: 'noext').extension, '');
      expect(FileItem(uri: 'u', displayName: 'ends-with-dot.').extension, '');
    });
  });
}
