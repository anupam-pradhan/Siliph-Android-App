/// Search PDF screen (section 14).
///
/// Include: search field, search results, match count, previous, next, highlight matches
/// Example: 3 of 12 matches
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/siliph_colors.dart';
import '../../app/theme/siliph_spacing.dart';
import '../../app/theme/siliph_typography.dart';
import '../../domain/models/file_item.dart';
import '../../domain/providers.dart';
import '../../domain/services/native_bridge.dart';
import '../../generated/siliph_bridge.g.dart';

enum _SearchPhase { searching, results, highlighting }

/// Search model
class _SearchModel {
  final String query;
  final List<String> results; // Text snippets
  final List<Rect> rects; // Position rectangles
  int currentIndex;
  int totalMatches;
  bool isSearching;

  _SearchModel({
    this.query = '',
    List<String>? results,
    List<Rect>? rects,
  })  : results = results ?? [],
       rects = rects ?? [],
       currentIndex = -1,
       totalMatches = 0,
       isSearching = false;

  _SearchModel copyWith({
    String? query,
    List<String>? results,
    List<Rect>? rects,
    int? currentIndex,
    int? totalMatches,
    bool? isSearching,
  }) {
    return _SearchModel(
      query: query ?? this.query,
      results: results ?? this.results,
      rects: rects ?? this.rects,
      currentIndex: currentIndex ?? this.currentIndex,
      totalMatches: totalMatches ?? this.totalMatches,
      isSearching: isSearching ?? this.isSearching,
    );
  }

  _SearchModel withSearching(bool searching) {
    return copyWith(isSearching: searching);
  }
}

/// Search PDF screen
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({
    super.key,
    required this.file,
  });

  final FileItem file;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState;
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  _SearchPhase _phase = _SearchPhase.searching;
  _SearchModel _model = _SearchModel();
  bool _isDirty = false;
  String? _error;

  // Search debounce
  Timer? _searchTimer;

  @override
  void initState() {
    super.initState();
    _searchTimer = Timer(const Duration(milliseconds: 500), _debounceSearch);
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    super.dispose();
  }

  void _debounceSearch() {
    // Search is triggered on blur or when user presses enter
  }

  // Start search
  void _startSearch(String query) {
    setState(() {
      _model = _model.copyWith(query: query, isSearching: true);
    });
    // TODO: Perform PDF text search
    // final results = await ref.read(pdfGatewayProvider).searchText(
    //   input: widget.file,
    //   text: query,
    // );
    // setState(() {
    //   _model = _model.copyWith(
    //     results: results.map((r) => r.text).toList(),
    //     rects: results.map((r) => r.rect).toList(),
    //     totalMatches: results.length,
    //     currentIndex: 0,
    //     isSearching: false,
    //   );
    // });
  }

  // Clear search
  void _clearSearch() {
    setState(() {
      _model = _SearchModel();
      _phase = _SearchPhase.searching;
    });
  }

  // Find next
  void _findNext() {
    if (_model.totalMatches > 0) {
      setState(() {
        _model = _model.copyWith(
          currentIndex: (_model.currentIndex + 1) % _model.totalMatches,
        );
      });
    }
  }

  // Find previous
  void _findPrevious() {
    if (_model.totalMatches > 0) {
      setState(() {
        _model = _model.copyWith(
          currentIndex:
              (_model.currentIndex - 1 + _model.totalMatches) % _model.totalMatches,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search PDF'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Close',
            onPressed: _clearSearch,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Phase indicator and search bar
            _buildPhaseAndSearch(),

            // Results info
            _buildResultsInfo(),

            // Navigation
            _buildNavigation(),

            // Canvas with highlights
            Expanded(
              child: _buildCanvas(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhaseAndSearch() {
    return Container(
      padding: const EdgeInsets.all(SiliphSpacing.md),
      color: SiliphColors.surface,
      child: Row(
        children: [
          // Search field
          Expanded(
            child: TextField(
              onChanged: (text) {
                _searchTimer?.cancel();
                _searchTimer = Timer(const Duration(milliseconds: 300), () {
                  _startSearch(text);
                });
              },
              onSubmitted: (text) {
                _searchTimer?.cancel();
                _startSearch(text);
              },
              decoration: const InputDecoration(
                hintText: 'Search in document...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
                suffixIcon: Icon(Icons.clear),
              ),
            ),
          ),
          const SizedBox(width: SiliphSpacing.sm),
          // Clear button (show when there's text)
          if (_model.query.isNotEmpty)
            TextButton(
              onPressed: _clearSearch,
              child: const Text('Clear'),
            ),
        ],
      ),
    );
  }

  Widget _buildResultsInfo() {
    return Container(
      padding: const EdgeInsets.all(SiliphSpacing.md),
      color: SiliphColors.surface,
      child: Row(
        children: [
          const Text(''),
          if (_model.totalMatches > 0)
            Text(
              '${_model.currentIndex + 1} of ${_model.totalMatches} matches',
              style: const TextStyle(fontWeight: FontWeight.bold),
            )
          else
            const Text('No matches found'),
      ]),
    );
  }

  Widget _buildNavigation() {
    return Container(
      padding: const EdgeInsets.all(SiliphSpacing.md),
      color: SiliphColors.surface,
      child: Row(
        children: [
          TextButton(
            onPressed: _findPrevious,
            child: const Text('Prev'),
          ),
          const SizedBox(width: SiliphSpacing.sm),
          TextButton(
            onPressed: _findNext,
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }

  Widget _buildCanvas() {
    return GestureDetector(
      onPanDown: (_) {
        FocusScope.of(context).unfocus();
      },
      child: Stack(
        children: [
          // PDF page area
          const Center(
            child: Icon(
              Icons.picture_as_pdf_outlined,
              size: 100,
              color: SiliphColors.outline,
            ),
          ),
          // Highlighted matches
          ..._buildHighlightedMatches(),
        ],
      ),
    );
  }

  List<Widget> _buildHighlightedMatches() {
    return _model.rects.map((rect) {
      return _HighlightRect(rect: rect, isCurrent: false);
    }).toList();
  }
}

// Highlight rect widget
class _HighlightRect extends StatelessWidget {
  final Rect rect;
  final bool isCurrent;

  const _HighlightRect({
    required this.rect,
    required this.isCurrent,
  });

  @override
  Widget build(BuildContext context) {
    final color = isCurrent
        ? SiliphColors.primary
        : SiliphColors.primary.withValues(alpha: 0.3);

    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}