/// On-device local NLP engine for text analysis, summarization, entity
/// extraction, and document QA with page citations (sections 41, 42).
///
/// 100% offline, local-first, zero external network API required.
library;

import '../../generated/siliph_bridge.g.dart';

/// Result of local document NLP analysis.
class DocumentAnalysisResult {
  const DocumentAnalysisResult({
    required this.executiveSummary,
    required this.keyPoints,
    required this.dates,
    required this.emails,
    required this.phoneNumbers,
    required this.urls,
    required this.wordCount,
    required this.characterCount,
    required this.readabilityScore,
    required this.pageCount,
  });

  final String executiveSummary;
  final List<String> keyPoints;
  final List<String> dates;
  final List<String> emails;
  final List<String> phoneNumbers;
  final List<String> urls;
  final int wordCount;
  final int characterCount;
  final String readabilityScore;
  final int pageCount;
}

/// One QA answer returned by local document chat matching.
class QaAnswer {
  const QaAnswer({
    required this.answerText,
    required this.pageNumber,
    required this.snippet,
    required this.relevanceScore,
  });

  final String answerText;
  final int pageNumber;
  final String snippet;
  final double relevanceScore;
}

/// On-device Local NLP Engine.
abstract final class AiNlpEngine {
  /// Regular expressions for local entity extraction.
  static final RegExp _emailRegExp =
      RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}');

  static final RegExp _phoneRegExp = RegExp(
    r'(\+?\d{1,3}[-.\s]?)?(\(?\d{2,4}\)?[-.\s]?)?\d{3,4}[-.\s]?\d{3,4}',
  );

  static final RegExp _dateRegExp = RegExp(
    r'\b(\d{1,2}[/-]\d{1,2}[/-]\d{2,4}|\d{4}[/-]\d{1,2}[/-]\d{1,2}|(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{1,2},?\s+\d{4})\b',
    caseSensitive: false,
  );

  static final RegExp _urlRegExp = RegExp(
    r'https?://[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(?:/[^\s]*)?',
  );

  /// Performs complete local NLP analysis on [fullText].
  static DocumentAnalysisResult analyzeText(
    String fullText, {
    int pageCount = 1,
  }) {
    final clean = fullText.trim();
    if (clean.isEmpty) {
      return const DocumentAnalysisResult(
        executiveSummary: 'No document text found for analysis.',
        keyPoints: [],
        dates: [],
        emails: [],
        phoneNumbers: [],
        urls: [],
        wordCount: 0,
        characterCount: 0,
        readabilityScore: 'N/A',
        pageCount: 0,
      );
    }

    final words = clean.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final wordCount = words.length;
    final characterCount = clean.length;

    // Entity extraction
    final emails = _emailRegExp
        .allMatches(clean)
        .map((m) => m.group(0)!)
        .toSet()
        .toList();

    final phoneNumbers = _phoneRegExp
        .allMatches(clean)
        .map((m) => m.group(0)!)
        .where((p) => p.replaceAll(RegExp(r'\D'), '').length >= 7)
        .toSet()
        .toList();

    final dates = _dateRegExp
        .allMatches(clean)
        .map((m) => m.group(0)!)
        .toSet()
        .toList();

    final urls = _urlRegExp
        .allMatches(clean)
        .map((m) => m.group(0)!)
        .toSet()
        .toList();

    // Readability metric (average word length)
    final avgWordLen =
        wordCount > 0 ? (characterCount / wordCount) : 0.0;
    final readability = avgWordLen > 6.2
        ? 'Technical / Dense'
        : (avgWordLen > 5.0 ? 'Standard / Medium' : 'Clear / Accessible');

    // Sentence extraction & scoring
    final rawSentences = clean
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((s) => s.trim())
        .where((s) => s.length > 15)
        .toList();

    if (rawSentences.isEmpty) {
      return DocumentAnalysisResult(
        executiveSummary: clean.length > 200 ? '${clean.substring(0, 200)}...' : clean,
        keyPoints: [clean],
        dates: dates,
        emails: emails,
        phoneNumbers: phoneNumbers,
        urls: urls,
        wordCount: wordCount,
        characterCount: characterCount,
        readabilityScore: readability,
        pageCount: pageCount,
      );
    }

    // Word frequency map for TF-IDF style sentence ranking
    final stopWords = {
      'the', 'is', 'at', 'which', 'on', 'a', 'an', 'and', 'or', 'in', 'to',
      'of', 'for', 'with', 'by', 'from', 'this', 'that', 'it', 'as', 'be',
      'are', 'was', 'were', 'been', 'has', 'have', 'had', 'not', 'can',
    };
    final freqMap = <String, int>{};
    for (final word in words) {
      final w = word.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (w.length > 2 && !stopWords.contains(w)) {
        freqMap[w] = (freqMap[w] ?? 0) + 1;
      }
    }

    // Score sentences by word frequency
    final scoredSentences = rawSentences.map((sentence) {
      final sentenceWords = sentence
          .toLowerCase()
          .split(RegExp(r'\s+'))
          .map((w) => w.replaceAll(RegExp(r'[^a-z0-9]'), ''))
          .where((w) => w.length > 2 && !stopWords.contains(w));

      var score = 0;
      for (final w in sentenceWords) {
        score += freqMap[w] ?? 0;
      }
      return (sentence: sentence, score: score);
    }).toList();

    scoredSentences.sort((a, b) => b.score.compareTo(a.score));

    // Executive summary (top 2-3 scored sentences in order of appearance)
    final topScored = scoredSentences.take(3).map((s) => s.sentence).toSet();
    final summarySentences = rawSentences
        .where((s) => topScored.contains(s))
        .take(3)
        .join(' ');

    // Key points (up to 4 top unique bullet sentences)
    final keyPoints = scoredSentences
        .take(4)
        .map((s) => s.sentence)
        .toList();

    return DocumentAnalysisResult(
      executiveSummary: summarySentences.isNotEmpty
          ? summarySentences
          : rawSentences.first,
      keyPoints: keyPoints,
      dates: dates,
      emails: emails,
      phoneNumbers: phoneNumbers,
      urls: urls,
      wordCount: wordCount,
      characterCount: characterCount,
      readabilityScore: readability,
      pageCount: pageCount,
    );
  }

  /// Finds the best matching passage and page number in [pages] for [query].
  static QaAnswer answerQuestion(String query, List<PageText> pages) {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty || pages.isEmpty) {
      return const QaAnswer(
        answerText: 'Please ask a valid question about the document.',
        pageNumber: 1,
        snippet: '',
        relevanceScore: 0.0,
      );
    }

    final queryKeywords = cleanQuery
        .split(RegExp(r'\s+'))
        .map((w) => w.replaceAll(RegExp(r'[^a-z0-9]'), ''))
        .where((w) => w.length > 2)
        .toSet();

    if (queryKeywords.isEmpty) {
      return const QaAnswer(
        answerText: 'Query too short or contains only generic words.',
        pageNumber: 1,
        snippet: '',
        relevanceScore: 0.0,
      );
    }

    var bestPageNum = 1;
    var bestSnippet = '';
    var maxMatchCount = 0;

    for (final page in pages) {
      final pageNum = page.pageIndex + 1;
      final sentences = page.text
          .split(RegExp(r'(?<=[.!?])\s+'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty);

      for (final sentence in sentences) {
        final sentenceLower = sentence.toLowerCase();
        var matchCount = 0;
        for (final kw in queryKeywords) {
          if (sentenceLower.contains(kw)) {
            matchCount++;
          }
        }

        if (matchCount > maxMatchCount) {
          maxMatchCount = matchCount;
          bestPageNum = pageNum;
          bestSnippet = sentence;
        }
      }
    }

    if (maxMatchCount == 0) {
      return QaAnswer(
        answerText:
            'No direct answer found for "$query" in the document text.',
        pageNumber: 1,
        snippet: pages.first.text.length > 150
            ? '${pages.first.text.substring(0, 150)}...'
            : pages.first.text,
        relevanceScore: 0.0,
      );
    }

    return QaAnswer(
      answerText: 'Based on Page $bestPageNum: "$bestSnippet"',
      pageNumber: bestPageNum,
      snippet: bestSnippet,
      relevanceScore: maxMatchCount / queryKeywords.length,
    );
  }
}
