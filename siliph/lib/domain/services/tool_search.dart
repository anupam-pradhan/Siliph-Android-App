/// Local, instant tool search with ranking (sections 6, 87, 159).
///
/// Pure Dart so it is trivially unit-testable and never touches the network.
library;

import '../models/tool_definition.dart';

/// A ranked search hit.
class ToolSearchResult {
  const ToolSearchResult(this.tool, this.score);

  final ToolDefinition tool;
  final int score;
}

/// Ranking weights follow section 159:
/// exact title > alias > keyword > category, with small boosts for
/// favorites and recently-used tools.
abstract final class _Score {
  static const int exactTitle = 100;
  static const int titlePrefix = 80;
  static const int titleContains = 60;
  static const int aliasMatch = 70;
  static const int keywordMatch = 50;
  static const int categoryMatch = 30;
  static const int favoriteBoost = 10;
  static const int recentBoost = 8;
}

/// Local tool search over a catalog.
class ToolSearch {
  const ToolSearch(this._catalog);

  final List<ToolDefinition> _catalog;

  /// Returns tools matching [query], ranked best-first.
  ///
  /// An empty or whitespace query returns the full catalog in display order.
  List<ToolDefinition> search(
    String query, {
    Set<String> favoriteIds = const {},
    Set<String> recentIds = const {},
  }) {
    final normalized = normalize(query);
    if (normalized.isEmpty) {
      return List.of(_catalog);
    }

    final hits = <ToolSearchResult>[];
    for (final tool in _catalog) {
      final score = _scoreTool(tool, normalized, favoriteIds, recentIds);
      if (score > 0) {
        hits.add(ToolSearchResult(tool, score));
      }
    }

    hits.sort((a, b) {
      if (b.score != a.score) return b.score.compareTo(a.score);
      // Stable tie-break: higher sortPriority, then title.
      if (b.tool.sortPriority != a.tool.sortPriority) {
        return b.tool.sortPriority.compareTo(a.tool.sortPriority);
      }
      return a.tool.title.compareTo(b.tool.title);
    });

    return hits.map((h) => h.tool).toList();
  }

  int _scoreTool(
    ToolDefinition tool,
    String query,
    Set<String> favoriteIds,
    Set<String> recentIds,
  ) {
    final title = normalize(tool.title);
    int score = 0;

    if (title == query) {
      score = _Score.exactTitle;
    } else if (title.startsWith(query)) {
      score = _Score.titlePrefix;
    } else if (title.contains(query)) {
      score = _Score.titleContains;
    }

    if (score == 0) {
      for (final alias in tool.aliases) {
        final a = normalize(alias);
        if (a == query || a.contains(query) || query.contains(a)) {
          score = _Score.aliasMatch;
          break;
        }
      }
    }

    if (score == 0) {
      for (final keyword in tool.keywords) {
        final k = normalize(keyword);
        if (k == query || k.startsWith(query) || query.contains(k)) {
          score = _Score.keywordMatch;
          break;
        }
      }
    }

    if (score == 0) {
      final categoryLabel = normalize(tool.category.label);
      if (categoryLabel == query || categoryLabel.startsWith(query)) {
        score = _Score.categoryMatch;
      }
    }

    if (score > 0) {
      if (favoriteIds.contains(tool.id)) score += _Score.favoriteBoost;
      if (recentIds.contains(tool.id)) score += _Score.recentBoost;
    }
    return score;
  }

  /// Lowercases and trims a query/term for matching.
  static String normalize(String input) => input.trim().toLowerCase();
}
