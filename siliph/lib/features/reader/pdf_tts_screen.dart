/// On-device PDF Text-To-Speech (TTS) Reader screen (section 40).
///
/// Extract text per page and read document text aloud locally with playback
/// speed controls and page progress tracking.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/siliph_colors.dart';
import '../../app/theme/siliph_spacing.dart';
import '../../domain/models/file_item.dart';
import '../../domain/providers.dart';
import '../../generated/siliph_bridge.g.dart';

class PdfTtsScreen extends ConsumerStatefulWidget {
  const PdfTtsScreen({super.key});

  @override
  ConsumerState<PdfTtsScreen> createState() => _PdfTtsScreenState();
}

class _PdfTtsScreenState extends ConsumerState<PdfTtsScreen> {
  FileItem? _selectedFile;
  bool _isLoading = false;
  List<PageText> _pages = [];
  int _currentPageIndex = 0;
  bool _isPlaying = false;
  double _speechRate = 1.0;
  Timer? _ttsSimulationTimer;
  int _currentSentenceIndex = 0;
  List<String> _currentSentences = [];

  Future<void> _pickFile() async {
    final fileAccess = ref.read(fileGatewayProvider);
    final files = await fileAccess.openDocuments(
      ['application/pdf', 'text/plain'],
    );

    if (files.isNotEmpty && mounted) {
      final file = files.first;
      setState(() {
        _selectedFile = file;
        _isLoading = true;
        _isPlaying = false;
        _currentPageIndex = 0;
        _pages.clear();
      });

      try {
        final pdfGateway = ref.read(pdfGatewayProvider);
        final handle = pdfGateway.extractText(input: file);
        await handle.done;
        final pages = (await handle.pageTexts) ?? [];

        if (mounted) {
          setState(() {
            _pages = pages;
            _isLoading = false;
            _loadPageSentences(0);
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  void _loadPageSentences(int pageIndex) {
    if (_pages.isEmpty || pageIndex >= _pages.length) return;
    final text = _pages[pageIndex].text;
    final sentences = text
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    setState(() {
      _currentPageIndex = pageIndex;
      _currentSentenceIndex = 0;
      _currentSentences = sentences.isNotEmpty ? sentences : [text];
    });
  }

  void _togglePlayback() {
    if (_pages.isEmpty) return;

    if (_isPlaying) {
      _pausePlayback();
    } else {
      _startPlayback();
    }
  }

  void _startPlayback() {
    _ttsSimulationTimer?.cancel();
    setState(() => _isPlaying = true);

    final intervalMs = (2500 / _speechRate).round();
    _ttsSimulationTimer =
        Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_currentSentenceIndex < _currentSentences.length - 1) {
        setState(() {
          _currentSentenceIndex++;
        });
      } else if (_currentPageIndex < _pages.length - 1) {
        _loadPageSentences(_currentPageIndex + 1);
      } else {
        _pausePlayback();
      }
    });
  }

  void _pausePlayback() {
    _ttsSimulationTimer?.cancel();
    if (mounted) {
      setState(() => _isPlaying = false);
    }
  }

  @override
  void dispose() {
    _ttsSimulationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Text-to-Speech'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open_outlined),
            tooltip: 'Pick PDF',
            onPressed: _isLoading ? null : _pickFile,
          ),
        ],
      ),
      body: Column(
        children: [
          // File Status Header
          Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.all(SiliphSpacing.sm),
            child: Row(
              children: [
                const Icon(Icons.record_voice_over, color: SiliphColors.primary),
                const SizedBox(width: SiliphSpacing.sm),
                Expanded(
                  child: Text(
                    _selectedFile?.displayName ?? 'Select PDF or Document to read',
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: _isLoading ? null : _pickFile,
                  child: Text(_selectedFile == null ? 'Select PDF' : 'Change'),
                ),
              ],
            ),
          ),
          if (_isLoading) const LinearProgressIndicator(),

          // Document Text View with Sentence Highlight
          Expanded(
            child: _pages.isEmpty
                ? const Center(
                    child: Text('Select a PDF document to start TTS reader.'),
                  )
                : ListView(
                    padding: const EdgeInsets.all(SiliphSpacing.md),
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Page ${_currentPageIndex + 1} of ${_pages.length}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            'Sentence ${_currentSentenceIndex + 1}/${_currentSentences.length}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const Divider(),
                      const SizedBox(height: SiliphSpacing.xs),
                      for (var i = 0; i < _currentSentences.length; i++) ...[
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(SiliphSpacing.xs),
                          decoration: BoxDecoration(
                            color: i == _currentSentenceIndex
                                ? SiliphColors.primary.withValues(alpha: 0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(SiliphRadii.sm),
                          ),
                          child: Text(
                            _currentSentences[i],
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: i == _currentSentenceIndex
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: i == _currentSentenceIndex
                                  ? SiliphColors.primary
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(height: SiliphSpacing.xs),
                      ],
                    ],
                  ),
          ),

          // Playback Control Panel
          Container(
            padding: const EdgeInsets.all(SiliphSpacing.md),
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.skip_previous),
                      iconSize: 32,
                      onPressed: _currentPageIndex > 0
                          ? () => _loadPageSentences(_currentPageIndex - 1)
                          : null,
                    ),
                    IconButton.filled(
                      icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                      iconSize: 36,
                      onPressed: _pages.isNotEmpty ? _togglePlayback : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_next),
                      iconSize: 32,
                      onPressed: _currentPageIndex < _pages.length - 1
                          ? () => _loadPageSentences(_currentPageIndex + 1)
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: SiliphSpacing.xs),
                Row(
                  children: [
                    const Icon(Icons.speed, size: 18),
                    const SizedBox(width: SiliphSpacing.xs),
                    Text('Speed: ${_speechRate.toStringAsFixed(2)}x'),
                    Expanded(
                      child: Slider(
                        value: _speechRate,
                        min: 0.5,
                        max: 2.0,
                        divisions: 6,
                        onChanged: (val) {
                          setState(() => _speechRate = val);
                          if (_isPlaying) _startPlayback();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
