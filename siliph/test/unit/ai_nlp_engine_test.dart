import 'package:flutter_test/flutter_test.dart';
import 'package:siliph/features/ai/ai_nlp_engine.dart';
import 'package:siliph/generated/siliph_bridge.g.dart';

void main() {
  group('AiNlpEngine Unit Tests', () {
    test('analyzeText extracts executive summary, key points and entities', () {
      const sampleText = '''
Siliph is an all-in-one local-first productivity app for Android.
The release target date is 2026-08-16.
For developer support, contact support@siliph.app or call +1 555 019 2831.
Visit our site at https://siliph.app for full privacy documentation.
Siliph processes all documents on-device without cloud uploads.
''';

      final result = AiNlpEngine.analyzeText(sampleText, pageCount: 3);

      expect(result.wordCount, greaterThan(20));
      expect(result.characterCount, greaterThan(100));
      expect(result.pageCount, equals(3));
      expect(result.executiveSummary, isNotEmpty);
      expect(result.keyPoints, isNotEmpty);
      expect(result.dates, contains('2026-08-16'));
      expect(result.emails, contains('support@siliph.app'));
      expect(result.urls, contains('https://siliph.app'));
    });

    test('answerQuestion matches query keywords to correct page citation', () {
      final pages = [
        PageText(
          pageIndex: 0,
          text: 'Introduction to Siliph PDF tools. Privacy is guaranteed.',
        ),
        PageText(
          pageIndex: 1,
          text:
              'Security policy statement: Passwords and encryption keys stay on your phone.',
        ),
        PageText(
          pageIndex: 2,
          text:
              'Contact details: reach support team at help@siliph.org for billing.',
        ),
      ];

      final answer = AiNlpEngine.answerQuestion('encryption keys', pages);

      expect(answer.pageNumber, equals(2)); // 1-indexed page 2
      expect(answer.snippet, contains('encryption keys'));
      expect(answer.relevanceScore, greaterThan(0.0));
    });

    test('answerQuestion handles missing or empty matches gracefully', () {
      final pages = [
        PageText(pageIndex: 0, text: 'Sample text without requested keywords.'),
      ];

      final answer = AiNlpEngine.answerQuestion('unrelated xyz query', pages);

      expect(answer.relevanceScore, equals(0.0));
      expect(answer.answerText, contains('No direct answer found'));
    });
  });
}
