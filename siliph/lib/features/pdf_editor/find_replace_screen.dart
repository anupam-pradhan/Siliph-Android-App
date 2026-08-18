/// Find & Replace screen (section 13).
///
/// Search field: Find text
/// Second field: Replace with
/// Actions: Find next, Find previous, Replace, Replace all
/// Show: 12 matches
/// Highlight matching text directly inside the PDF
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

enum _FindPhase { finding, replacing, results }

/// Find & Replace model
class _FindReplaceModel {
  final String findText;
  final String replaceWith;
  final List<int> matches; // Line numbers or positions
  bool _isSearching;
  int _currentMatchIndex;

  _FindReplaceModel({
    this.findText = '',
    this.replaceWith = '',
    List<int>? matches,
  })  : _matches = matches ?? [],
       _isSearching = false,
       _currentMatchIndex = -1;

  final List<int> _matches;

  List<int> get matches => _matches;

  int get currentMatchIndex => _currentMatchIndex;
  set currentMatchIndex(int index) {
    _currentMatchIndex = index.clamp(0, _matches.length - 1);
  }

  int get matchCount => _matches.length;

  _FindReplaceModel copyWith({
    String? findText,
    String? replaceWith,
    List<int>? matches,
    bool? isSearching,
    int? currentMatchIndex,
  }) {
    return _FindReplaceModel(
      findText: findText ?? this.findText,
      replaceWith: replaceWith ?? this.replaceWith,
      matches: matches ?? this._matches,
    )..currentMatchIndex = currentMatchIndex ?? this._currentMatchIndex;
  }

  _FindReplaceModel withSearching(bool searching) {
    return copyWith(isSearching: searching)..currentMatchIndex = _currentMatchIndex;
  }
}

/// Find & Replace screen
class FindReplaceScreen extends ConsumerStatefulWidget {
  const FindReplaceScreen({
    super.key,
    required this.file,
    required this.pageNumber,
  });

  final FileItem file;
  final int pageNumber;

  @override
  ConsumerState<FindReplaceScreen> createState() => _FindReplaceScreenState;
}

class _FindReplaceScreenState extends ConsumerState<FindReplaceScreen> {
  _FindPhase _phase = _FindPhase.finding;
  _FindReplaceModel _model = _FindReplaceModel();
  bool _isDirty = false;
  String? _error;

  // Search results highlighting state
  final List<Rect> _matchedRects = [];
  int _highlightIndex = -1;

  @override
  void initState() {
    super.initState();
    // TODO: Initialize PDF text search
    // _model = _FindReplaceModel(
    //   findText: '',
    //   replaceWith: '',
    //   matches: [],
    // );
  }

  @override
  void dispose() {
    super.dispose();
  }

  // Start finding
  void _startFind() {
    setState(() {
      _phase = _FindPhase.finding;
      _isDirty = false;
    });
    // TODO: Perform text search in PDF
    // final results = await ref.read(pdfGatewayProvider).searchText(
    //   input: widget.file,
    //   pageNumber: widget.pageNumber,
    //   text: _model.findText,
    // );
    // setState(() {
    //   _model = _model.copyWith(matches: results.map((r) => r.lineNumber).toList());
    //   _highlightIndex = 0;
    // });
  }

  // Find next
  void _findNext() {
    setState(() {
      if (_model.matchCount > 0) {
        _model.currentMatchIndex =
            (_model.currentMatchIndex + 1) % _model.matchCount;
      }
    });
  }

  // Find previous
  void _findPrevious() {
    setState(() {
      if (_model.matchCount > 0) {
        _model.currentMatchIndex =
            (_model.currentMatchIndex - 1 + _model.matchCount) % _model.matchCount;
      }
    });
  }

  // Replace current
  void _replaceCurrent() {
    setState(() {
      // TODO: Replace text at current match
      _isDirty = true;
    });
  }

  // Replace all
  void _replaceAll() {
    setState(() {
      // TODO: Replace all occurrences
      _isDirty = true;
    });
  }

  // Cancel
  void _cancel() {
    setState(() => _phase = _FindPhase.finding);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find & Replace'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Close',
            onPressed: _cancel,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Phase indicator
            _buildPhaseIndicator(),

            // Search bar
            _buildSearchBar(),

            // Results info
            _buildResultsInfo(),

            // Action buttons
            _buildActionButtons(),

            // Match display
            _buildMatchDisplay(),

            // Canvas with highlights
            Expanded(
              child: _buildCanvas(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhaseIndicator() {
    return Padding(
      padding: const EdgeInsets.all(SiliphSpacing.md),
      child: Row(
        children: [
          _PhaseChip(
            phase: _FindPhase.finding,
            label: 'Find',
            active: _phase == _FindPhase.finding,
          ),
          const SizedBox(width: SiliphSpacing.sm),
          _PhaseChip(
            phase: _FindPhase.replacing,
            label: 'Replace',
            active: _phase == _FindPhase.replacing,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(SiliphSpacing.md),
      color: SiliphColors.surface,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: (text) {
                setState(() {
                  _model = _model.copyWith(findText: text);
                });
              },
              decoration: const InputDecoration(
                hintText: 'Find',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.search),
              ),
            ),
          ),
          const SizedBox(width: SiliphSpacing.sm),
          ElevatedButton(
            onPressed: _startFind,
            child: const Text('Find'),
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
          const Text('Match count:'),
          Text(
            _model.matchCount.toString(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const Text(' of 12 matches'),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(SiliphSpacing.md),
      color: SiliphColors.surface,
      child: Row(
        children: [
          TextButton(
            onPressed: _findPrevious,
            child: const Text('Previous'),
          ),
          const SizedBox(width: SiliphSpacing.sm),
          TextButton(
            onPressed: _findNext,
            child: const Text('Next'),
          ),
          const SizedBox(width: SiliphSpacing.sm),
          TextButton(
            onPressed: _replaceCurrent,
            child: const Text('Replace'),
          ),
          const SizedBox(width: SiliphSpacing.sm),
          TextButton(
            onPressed: _replaceAll,
            child: const Text('Replace all'),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchDisplay() {
    return Container(
      padding: const EdgeInsets.all(SiliphSpacing.md),
      color: SiliphColors.surface,
      child: Row(
        children: [
          const Text(''),
          Text(
            '${_model.currentMatchIndex + 1} of ${_model.matchCount}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildCanvas() {
    return GestureDetector(
      onPanDown: (_) {
        // Dismiss keyboard
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
    return _model.matches.map((matchIndex) {
      final rect = _getMatchRect(matchIndex);
      return _HighlightRect(
        rect: rect,
        isCurrent: _highlightIndex == matchIndex,
      );
    }).toList();
  }

  Rect _getMatchRect(int matchIndex) {
    // TODO: Get actual rect from PDF text search
    // For now, return a placeholder rect
    final pageHeight = 800.0;
    final pageWidth = 600.0;
    final matchCount = _model.matchCount.clamp(1, 12);
    final index = matchIndex.clamp(0, matchCount - 1);
    
    // Distribute matches horizontally across the page
    final x = 50 + (index * (pageWidth - 100) / matchCount);
    final y = 100 + (index % 3) * 100;
    final width = (pageWidth - 100) / matchCount - 20;
    final height = 30.0;
    
    return Rect.fromLTWH(x, y, width, height);
  }
}

// Phase chip
class _PhaseChip extends StatelessWidget {
  final _FindPhase phase;
  final String label;
  final bool active;

  const _PhaseChip({
    required this.phase,
    required this.label,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: active,
      onSelected: (_) => setState(() => _phase = phase),
      selectedColor: SiliphColors.primary.withValues(alpha: 0.15),
      backgroundColor: Colors.transparent,
    );
  }
}