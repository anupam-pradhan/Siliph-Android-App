/// Unit tests for file-name validation helpers (section 34).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:siliph/domain/services/file_names.dart';

void main() {
  group('renameProblem', () {
    test('accepts ordinary names', () {
      expect(renameProblem('Report 2026.pdf'), isNull);
      expect(renameProblem('  trimmed  '), isNull);
    });

    test('rejects empty and whitespace-only names', () {
      expect(renameProblem(''), 'Enter a file name.');
      expect(renameProblem('   '), 'Enter a file name.');
    });

    test('rejects path-like names', () {
      expect(renameProblem('a/b'), 'File names cannot contain slashes.');
      expect(renameProblem('.'), 'That name is not allowed.');
      expect(renameProblem('..'), 'That name is not allowed.');
    });

    test('rejects very long names', () {
      expect(renameProblem('x' * 201), 'That name is too long.');
      expect(renameProblem('x' * 200), isNull);
    });
  });

  group('isEffectivelyUnchanged', () {
    test('ignores surrounding whitespace', () {
      expect(isEffectivelyUnchanged(' a.pdf ', 'a.pdf'), isTrue);
      expect(isEffectivelyUnchanged('b.pdf', 'a.pdf'), isFalse);
    });
  });

  group('splitExtension', () {
    test('splits name and extension', () {
      expect(splitExtension('Report.PDF'), ('Report', '.PDF'));
      expect(splitExtension('a.b.c'), ('a.b', '.c'));
    });

    test('keeps hidden files and bare names whole', () {
      expect(splitExtension('.gitignore'), ('.gitignore', ''));
      expect(splitExtension('archive'), ('archive', ''));
      expect(splitExtension('name.'), ('name.', ''));
    });
  });
}
