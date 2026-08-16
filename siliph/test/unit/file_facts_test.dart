/// Unit tests for the pure file-fact display helpers (section 34).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:siliph/domain/models/file_item.dart';
import 'package:siliph/domain/services/file_facts.dart';

void main() {
  group('formatModifiedMillis', () {
    test('unset timestamps read Unknown', () {
      expect(formatModifiedMillis(0), 'Unknown');
      expect(formatModifiedMillis(-5), 'Unknown');
    });

    test('formats local time zero-padded', () {
      final millis = DateTime(2026, 8, 16, 9, 5).millisecondsSinceEpoch;
      expect(formatModifiedMillis(millis), '2026-08-16 09:05');
    });
  });

  group('providerAuthority', () {
    test('extracts the authority of a content URI', () {
      expect(
        providerAuthority(
          'content://com.android.providers.downloads.documents/document/42',
        ),
        'com.android.providers.downloads.documents',
      );
    });

    test('non-content URIs yield empty', () {
      expect(providerAuthority('file:///sdcard/x.pdf'), '');
      expect(providerAuthority('content://auth'), 'auth');
    });
  });

  group('folderHint', () {
    test('keeps the human folder name from a tree URI', () {
      expect(
        folderHint(
          'content://com.android.externalstorage.documents/'
          'tree/primary%3ADocuments',
        ),
        'Documents',
      );
    });

    test('falls back to the raw URI when unparsable', () {
      expect(folderHint('not a uri at all'), 'not a uri at all');
    });
  });

  group('formatBytes', () {
    test('formats units with one decimal except bytes', () {
      expect(formatBytes(0), '0B');
      expect(formatBytes(512), '512B');
      expect(formatBytes(1024), '1.0KB');
      expect(formatBytes(1048576), '1.0MB');
      expect(formatBytes(4 * 1024 * 1024 * 1024), '4.0GB');
    });

    test('drops the decimal for large values', () {
      expect(formatBytes(1200 * 1024), '1.2MB');
      expect(formatBytes(150 * 1024 * 1024), '150MB');
    });

    test('negative sizes read Unknown', () {
      expect(formatBytes(-1), 'Unknown');
    });
  });

  group('displayNameFromUri', () {
    test('decodes the last segment of a document URI', () {
      expect(
        displayNameFromUri(
          'content://com.android.externalstorage.documents/'
          'document/primary%3ADocuments%2Fphoto.jpg',
        ),
        'photo.jpg',
      );
    });

    test('falls back to the raw URI when unparsable', () {
      expect(displayNameFromUri('plain text'), 'plain text');
    });
  });

  group('baseName', () {
    test('drops the extension', () {
      expect(
        baseName(const FileItem(
            uri: 'content://test/photo.jpg', displayName: 'photo.jpg')),
        'photo',
      );
    });

    test('keeps names without a usable extension', () {
      expect(
        baseName(const FileItem(
            uri: 'content://test/README', displayName: 'README')),
        'README',
      );
      expect(
        baseName(const FileItem(
            uri: 'content://test/.hidden', displayName: '.hidden')),
        '.hidden',
      );
    });
  });
}
