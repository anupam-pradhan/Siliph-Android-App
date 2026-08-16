/// PDF Page Numbering workflow screen (section 17).
///
/// Overlays customizable page numbers on every page of a PDF.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/siliph_colors.dart';
import '../../app/theme/siliph_spacing.dart';
import '../../domain/models/file_item.dart';
import '../../domain/providers.dart';
import '../../generated/siliph_bridge.g.dart';

class PdfPageNumbersScreen extends ConsumerStatefulWidget {
  const PdfPageNumbersScreen({super.key});

  @override
  ConsumerState<PdfPageNumbersScreen> createState() =>
      _PdfPageNumbersScreenState();
}

class _PdfPageNumbersScreenState extends ConsumerState<PdfPageNumbersScreen> {
  FileItem? _selectedFile;
  PdfInfo? _info;
  String _position = 'bottom-center';
  String _format = 'page_x_of_y';
  int _startPage = 1;

  bool _isProcessing = false;
  double _progress = 0.0;
  String? _error;
  FileItem? _outputFile;

  Future<void> _pickFile() async {
    setState(() {
      _error = null;
      _outputFile = null;
    });
    final fileAccess = ref.read(fileGatewayProvider);
    final files = await fileAccess.openDocuments(
      ['application/pdf'],
    );

    if (files.isNotEmpty && mounted) {
      final file = files.first;
      setState(() {
        _selectedFile = file;
      });

      try {
        final pdfGateway = ref.read(pdfGatewayProvider);
        final info = await pdfGateway.inspect(file);
        if (mounted) setState(() => _info = info);
      } catch (e) {
        if (mounted) setState(() => _error = 'Invalid PDF file.');
      }
    }
  }

  Future<void> _processPageNumbers() async {
    if (_selectedFile == null) return;

    final fileAccess = ref.read(fileGatewayProvider);
    final targetName =
        '${_selectedFile!.displayName.replaceAll('.pdf', '')}_numbered.pdf';

    final output = await fileAccess.createDocument(
      mimeType: 'application/pdf',
      displayName: targetName,
    );

    if (output == null) return;

    setState(() {
      _isProcessing = true;
      _progress = 0.0;
      _error = null;
      _outputFile = null;
    });

    try {
      final pdfGateway = ref.read(pdfGatewayProvider);
      final handle = pdfGateway.addPageNumbers(
        input: _selectedFile!,
        position: _position,
        format: _format,
        startPage: _startPage,
        output: output,
      );

      handle.progress.listen((p) {
        if (mounted) setState(() => _progress = p);
      });

      await handle.done;

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _progress = 1.0;
          _outputFile = output;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _error = 'Failed to add page numbers: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Page Numbers'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(SiliphSpacing.md),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(SiliphSpacing.md),
              child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf, color: SiliphColors.primary),
                  const SizedBox(width: SiliphSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedFile?.displayName ?? 'Select PDF file',
                          style: Theme.of(context).textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_info != null)
                          Text('${_info!.pageCount} pages • ${_selectedFile!.formattedSize}'),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _isProcessing ? null : _pickFile,
                    child: Text(_selectedFile == null ? 'Pick PDF' : 'Change'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: SiliphSpacing.md),
          if (_selectedFile != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(SiliphSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Page Number Options',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: SiliphSpacing.sm),
                    DropdownButtonFormField<String>(
                      initialValue: _position,
                      decoration: const InputDecoration(
                        labelText: 'Position',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'bottom-center', child: Text('Bottom Center')),
                        DropdownMenuItem(
                            value: 'bottom-right', child: Text('Bottom Right')),
                        DropdownMenuItem(
                            value: 'top-center', child: Text('Top Center')),
                        DropdownMenuItem(
                            value: 'top-right', child: Text('Top Right')),
                      ],
                      onChanged: _isProcessing
                          ? null
                          : (val) => setState(() => _position = val!),
                    ),
                    const SizedBox(height: SiliphSpacing.md),
                    DropdownButtonFormField<String>(
                      initialValue: _format,
                      decoration: const InputDecoration(
                        labelText: 'Number Format',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'page_x_of_y', child: Text('Page X of Y')),
                        DropdownMenuItem(value: 'x', child: Text('X (1, 2, 3...)')),
                        DropdownMenuItem(
                            value: 'dash_x_dash', child: Text('- X -')),
                      ],
                      onChanged: _isProcessing
                          ? null
                          : (val) => setState(() => _format = val!),
                    ),
                    const SizedBox(height: SiliphSpacing.md),
                    TextFormField(
                      initialValue: _startPage.toString(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Start Numbering From',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) {
                        final parsed = int.tryParse(val);
                        if (parsed != null && parsed >= 1) {
                          _startPage = parsed;
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: SiliphSpacing.md),
            FilledButton.icon(
              onPressed: _isProcessing ? null : _processPageNumbers,
              icon: const Icon(Icons.numbers),
              label: const Text('Add Page Numbers'),
            ),
            const SizedBox(height: SiliphSpacing.md),
          ],
          if (_isProcessing) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(SiliphSpacing.md),
                child: Column(
                  children: [
                    const Text('Applying page numbers...'),
                    const SizedBox(height: SiliphSpacing.xs),
                    LinearProgressIndicator(value: _progress),
                  ],
                ),
              ),
            ),
          ],
          if (_error != null) ...[
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(SiliphSpacing.md),
                child: Text(_error!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer)),
              ),
            ),
          ],
          if (_outputFile != null) ...[
            Card(
              color: SiliphColors.success.withValues(alpha: 0.15),
              child: Padding(
                padding: const EdgeInsets.all(SiliphSpacing.md),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: SiliphColors.success),
                    const SizedBox(width: SiliphSpacing.sm),
                    Expanded(
                      child: Text('Saved numbered PDF as ${_outputFile!.displayName}'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
