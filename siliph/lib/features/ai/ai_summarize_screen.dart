/// On-device AI Summarizer workflow screen (sections 41, 42).
///
/// Extract executive summaries, key bullet points, and entities locally
/// without sending document text to cloud servers.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/siliph_colors.dart';
import '../../app/theme/siliph_spacing.dart';
import '../../domain/models/file_item.dart';
import '../../domain/providers.dart';
import 'ai_nlp_engine.dart';

class AiSummarizeScreen extends ConsumerStatefulWidget {
  const AiSummarizeScreen({super.key});

  @override
  ConsumerState<AiSummarizeScreen> createState() => _AiSummarizeScreenState();
}

class _AiSummarizeScreenState extends ConsumerState<AiSummarizeScreen> {
  FileItem? _selectedFile;
  bool _isProcessing = false;
  double _progress = 0.0;
  String? _error;
  DocumentAnalysisResult? _result;

  Future<void> _pickFile() async {
    setState(() {
      _error = null;
    });
    final fileAccess = ref.read(fileGatewayProvider);
    final files = await fileAccess.openDocuments(
      ['application/pdf', 'image/*'],
    );

    if (files.isNotEmpty && mounted) {
      setState(() {
        _selectedFile = files.first;
        _result = null;
      });
      _runSummarization(files.first);
    }
  }

  Future<void> _runSummarization(FileItem file) async {
    setState(() {
      _isProcessing = true;
      _progress = 0.1;
      _error = null;
    });

    try {
      final isPdf = file.displayName.toLowerCase().endsWith('.pdf') ||
          (file.mimeType?.contains('pdf') ?? false);

      String fullText = '';
      int pageCount = 1;

      if (isPdf) {
        final pdfGateway = ref.read(pdfGatewayProvider);
        final info = await pdfGateway.inspect(file);
        pageCount = info.pageCount;

        final handle = pdfGateway.extractText(input: file);
        handle.progress.listen((p) {
          if (mounted) setState(() => _progress = 0.1 + (p * 0.7));
        });

        await handle.done;
        final pages = (await handle.pageTexts) ?? [];
        fullText = pages.map((p) => p.text).join('\n\n');

        // Fallback to OCR if text extraction came up sparse
        if (fullText.trim().length < 50) {
          final ocrGateway = ref.read(ocrGatewayProvider);
          final ocrHandle = ocrGateway.recognizePdf(input: file, language: 'latin');
          await ocrHandle.done;
          final blocks = (await ocrHandle.ocrBlocks) ?? [];
          fullText = blocks.map((b) => b.text).join(' ');
        }
      } else {
        final ocrGateway = ref.read(ocrGatewayProvider);
        final handle = ocrGateway.recognizeImage(image: file, language: 'latin');
        await handle.done;
        final blocks = (await handle.ocrBlocks) ?? [];
        fullText = blocks.map((b) => b.text).join(' ');
      }

      final analysis = AiNlpEngine.analyzeText(fullText, pageCount: pageCount);

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _progress = 1.0;
          _result = analysis;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _error = 'Failed to analyze document: ${e.toString()}';
        });
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Summarizer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open_outlined),
            tooltip: 'Pick document',
            onPressed: _isProcessing ? null : _pickFile,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(SiliphSpacing.md),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(SiliphSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: SiliphColors.primary),
                      const SizedBox(width: SiliphSpacing.sm),
                      Expanded(
                        child: Text(
                          _selectedFile?.displayName ?? 'Select PDF or Image document',
                          style: Theme.of(context).textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _isProcessing ? null : _pickFile,
                        icon: const Icon(Icons.upload_file, size: 18),
                        label: Text(_selectedFile == null ? 'Pick File' : 'Change'),
                      ),
                    ],
                  ),
                  if (_selectedFile != null) ...[
                    const SizedBox(height: SiliphSpacing.xs),
                    Text(
                      '${_selectedFile!.formattedSize} • ${_selectedFile!.mimeType ?? "Document"}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: SiliphSpacing.md),
          if (_isProcessing) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(SiliphSpacing.lg),
                child: Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: SiliphSpacing.md),
                    Text(
                      'Analyzing document text on-device...',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: SiliphSpacing.xs),
                    LinearProgressIndicator(value: _progress),
                  ],
                ),
              ),
            ),
          ] else if (_error != null) ...[
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(SiliphSpacing.md),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                        color: Theme.of(context).colorScheme.onErrorContainer),
                    const SizedBox(width: SiliphSpacing.sm),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else if (_result != null) ...[
            // Document Metrics Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(SiliphSpacing.md),
                child: Wrap(
                  spacing: SiliphSpacing.sm,
                  runSpacing: SiliphSpacing.xs,
                  children: [
                    Chip(
                      avatar: const Icon(Icons.tag, size: 16),
                      label: Text('${_result!.wordCount} Words'),
                    ),
                    Chip(
                      avatar: const Icon(Icons.pages_outlined, size: 16),
                      label: Text('${_result!.pageCount} Pages'),
                    ),
                    Chip(
                      avatar: const Icon(Icons.speed, size: 16),
                      label: Text('Readability: ${_result!.readabilityScore}'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: SiliphSpacing.md),
            // Executive Summary Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(SiliphSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Executive Summary',
                            style: Theme.of(context).textTheme.titleMedium),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 18),
                          tooltip: 'Copy summary',
                          onPressed: () => _copyToClipboard(
                              _result!.executiveSummary, 'Executive summary'),
                        ),
                      ],
                    ),
                    const Divider(),
                    SelectableText(
                      _result!.executiveSummary,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: SiliphSpacing.md),
            // Key Points Card
            if (_result!.keyPoints.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(SiliphSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Key Takeaways',
                          style: Theme.of(context).textTheme.titleMedium),
                      const Divider(),
                      for (final point in _result!.keyPoints) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: SiliphSpacing.xxs),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• ',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: SiliphColors.primary)),
                              Expanded(
                                child: SelectableText(
                                  point,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: SiliphSpacing.md),
            ],
            // Entity Extractions Card
            if (_result!.dates.isNotEmpty ||
                _result!.emails.isNotEmpty ||
                _result!.phoneNumbers.isNotEmpty ||
                _result!.urls.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(SiliphSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Extracted Entities',
                          style: Theme.of(context).textTheme.titleMedium),
                      const Divider(),
                      if (_result!.dates.isNotEmpty) ...[
                        Text('Dates Found: ${_result!.dates.join(", ")}',
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: SiliphSpacing.xs),
                      ],
                      if (_result!.emails.isNotEmpty) ...[
                        Text('Emails: ${_result!.emails.join(", ")}',
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: SiliphSpacing.xs),
                      ],
                      if (_result!.phoneNumbers.isNotEmpty) ...[
                        Text('Phones: ${_result!.phoneNumbers.join(", ")}',
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: SiliphSpacing.xs),
                      ],
                      if (_result!.urls.isNotEmpty) ...[
                        Text('Web Links: ${_result!.urls.join(", ")}',
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: SiliphSpacing.md),
            ],
          ] else ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.all(SiliphSpacing.xl),
                child: Text('Pick a document above to generate an instant summary.'),
              ),
            ),
          ],
          const Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_outlined, size: 14, color: SiliphColors.onSurfaceVariant),
                SizedBox(width: SiliphSpacing.xxs),
                Text(
                  '100% On-Device & Private. No data uploaded.',
                  style: TextStyle(fontSize: 12, color: SiliphColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
