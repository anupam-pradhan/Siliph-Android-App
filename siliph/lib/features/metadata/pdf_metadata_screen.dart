/// PDF Metadata workflow (section 15, section 50 tool-screen standard).
///
/// Preview + edit + strip the document-information dictionary. Edits are
/// written to a copy; the original is never touched.
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
import '../../domain/services/pdf_plans.dart';
import '../../generated/siliph_bridge.g.dart';

enum _Phase { pick, loading, edit, running, done }

class PdfMetadataScreen extends ConsumerStatefulWidget {
  const PdfMetadataScreen({super.key});

  @override
  ConsumerState<PdfMetadataScreen> createState() => _PdfMetadataScreenState();
}

class _PdfMetadataScreenState extends ConsumerState<PdfMetadataScreen> {
  _Phase _phase = _Phase.pick;
  FileItem? _input;
  bool _picking = false;
  double _progress = 0;
  String? _error;
  FileItem? _output;
  String? _doneAction;
  StreamSubscription<double>? _progressSub;

  final _title = TextEditingController();
  final _author = TextEditingController();
  final _subject = TextEditingController();
  final _keywords = TextEditingController();
  final _creator = TextEditingController();
  final _producer = TextEditingController();

  @override
  void dispose() {
    final sub = _progressSub;
    _progressSub = null;
    if (sub != null) unawaited(sub.cancel());
    _title.dispose();
    _author.dispose();
    _subject.dispose();
    _keywords.dispose();
    _creator.dispose();
    _producer.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final picked = await ref
          .read(fileGatewayProvider)
          .openDocuments(const ['application/pdf']);
      if (!mounted) return;
      if (picked.isEmpty) {
        setState(() => _picking = false);
        return;
      }
      final file = picked.first;
      setState(() {
        _picking = false;
        _input = file;
        _phase = _Phase.loading;
      });
      final metadata = await ref.read(pdfGatewayProvider).readMetadata(file);
      if (!mounted) return;
      _fill(metadata);
      setState(() {
        _output = null;
        _phase = _Phase.edit;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _picking = false;
        _phase = _Phase.pick;
        _error = e is BridgeException
            ? e.userMessage
            : 'Could not read that PDF.';
      });
    }
  }

  void _fill(PdfMetadata metadata) {
    _title.text = metadata.title ?? '';
    _author.text = metadata.author ?? '';
    _subject.text = metadata.subject ?? '';
    _keywords.text = metadata.keywords ?? '';
    _creator.text = metadata.creator ?? '';
    _producer.text = metadata.producer ?? '';
  }

  Future<void> _save({required bool removeAll}) async {
    final input = _input;
    if (input == null) return;

    if (removeAll) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Remove all metadata?'),
          content: const Text(
            'Title, author, subject, keywords and tool details will be '
            'stripped from the saved copy.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    final output = await ref.read(fileGatewayProvider).createDocument(
          mimeType: 'application/pdf',
          displayName:
              '${stripPdfExtension(input.displayName)}-metadata.pdf',
        );
    if (!mounted) return;
    if (output == null) return;

    final handle = ref.read(pdfGatewayProvider).writeMetadata(
          input: input,
          metadata: PdfMetadata(
            title: _title.text.trim().isEmpty ? null : _title.text.trim(),
            author: _author.text.trim().isEmpty ? null : _author.text.trim(),
            subject:
                _subject.text.trim().isEmpty ? null : _subject.text.trim(),
            keywords:
                _keywords.text.trim().isEmpty ? null : _keywords.text.trim(),
            creator:
                _creator.text.trim().isEmpty ? null : _creator.text.trim(),
            producer:
                _producer.text.trim().isEmpty ? null : _producer.text.trim(),
          ),
          removeAll: removeAll,
          output: output,
        );
    _progressSub = handle.progress.listen((value) {
      if (mounted) setState(() => _progress = value);
    });
    setState(() {
      _phase = _Phase.running;
      _progress = 0;
      _error = null;
    });
    try {
      await handle.done;
      if (!mounted) return;
      ref.read(importedFilesProvider.notifier).addAll([output]);
      setState(() {
        _output = output;
        _doneAction = removeAll ? 'removed' : 'saved';
        _phase = _Phase.done;
      });
    } catch (e) {
      if (!mounted) return;
      if (e is BridgeException && e.isCancelled) return;
      setState(() {
        _phase = _Phase.edit;
        _error = e is BridgeException ? e.userMessage : 'Saving failed.';
      });
    } finally {
      final sub = _progressSub;
      _progressSub = null;
      if (sub != null) unawaited(sub.cancel());
    }
  }

  @override
  Widget build(BuildContext context) {
    final input = _input;
    final output = _output;

    return Scaffold(
      appBar: AppBar(title: const Text('PDF Metadata')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: switch (_phase) {
                _Phase.pick => _PickView(picking: _picking, onPick: _pick),
                _Phase.loading => const Center(
                    child: CircularProgressIndicator(),
                  ),
                _Phase.edit => _EditView(
                    file: input!,
                    title: _title,
                    author: _author,
                    subject: _subject,
                    keywords: _keywords,
                    creator: _creator,
                    producer: _producer,
                    onSave: () => _save(removeAll: false),
                    onRemoveAll: () => _save(removeAll: true),
                  ),
                _Phase.running => _ProgressView(progress: _progress),
                _Phase.done => _DoneView(
                    output: output!,
                    action: _doneAction ?? 'saved',
                    onRestart: () => setState(() {
                          _phase = _Phase.pick;
                          _input = null;
                          _output = null;
                        }),
                  ),
              },
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(SiliphSpacing.md),
                child: _ErrorBanner(message: _error!),
              ),
          ],
        ),
      ),
    );
  }
}

class _PickView extends StatelessWidget {
  const _PickView({required this.picking, required this.onPick});

  final bool picking;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SiliphSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, size: 64, color: SiliphColors.primary),
            const SizedBox(height: SiliphSpacing.md),
            Text('PDF Metadata',
                style: Theme.of(context).textTheme.headlineSmallStyle),
            const SizedBox(height: SiliphSpacing.xs),
            Text(
              'View, edit or strip the hidden details stored inside a PDF.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: SiliphSpacing.lg),
            FilledButton.icon(
              onPressed: picking ? null : onPick,
              icon: picking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined),
              label: Text(picking ? 'Opening…' : 'Choose PDF'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditView extends StatelessWidget {
  const _EditView({
    required this.file,
    required this.title,
    required this.author,
    required this.subject,
    required this.keywords,
    required this.creator,
    required this.producer,
    required this.onSave,
    required this.onRemoveAll,
  });

  final FileItem file;
  final TextEditingController title;
  final TextEditingController author;
  final TextEditingController subject;
  final TextEditingController keywords;
  final TextEditingController creator;
  final TextEditingController producer;
  final VoidCallback onSave;
  final VoidCallback onRemoveAll;

  Widget _field(BuildContext context, String label, TextEditingController c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SiliphSpacing.sm),
      child: TextField(
        controller: c,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            SiliphSpacing.md, SiliphSpacing.md, SiliphSpacing.md, 0,
          ),
          child: Text(file.displayName,
              style: Theme.of(context).textTheme.titleMediumStyle),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(SiliphSpacing.md),
            children: [
              _field(context, 'Title', title),
              _field(context, 'Author', author),
              _field(context, 'Subject', subject),
              _field(context, 'Keywords', keywords),
              _field(context, 'Creator', creator),
              _field(context, 'Producer', producer),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(SiliphSpacing.md),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onSave,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save copy with these details'),
                ),
              ),
              const SizedBox(height: SiliphSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onRemoveAll,
                  icon: const Icon(Icons.cleaning_services_outlined),
                  label: const Text('Remove all metadata'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProgressView extends StatelessWidget {
  const _ProgressView({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SiliphSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Saving… ${(progress * 100).toInt()}%',
                style: Theme.of(context).textTheme.titleMediumStyle),
            const SizedBox(height: SiliphSpacing.md),
            LinearProgressIndicator(value: progress),
          ],
        ),
      ),
    );
  }
}

class _DoneView extends StatelessWidget {
  const _DoneView({
    required this.output,
    required this.action,
    required this.onRestart,
  });

  final FileItem output;
  final String action;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SiliphSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 64, color: SiliphColors.success),
            const SizedBox(height: SiliphSpacing.md),
            Text(action == 'removed' ? 'Metadata removed' : 'Metadata saved',
                style: Theme.of(context).textTheme.headlineSmallStyle),
            const SizedBox(height: SiliphSpacing.xs),
            Text(
              'Saved as "${output.displayName}". The original file is '
              'unchanged.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: SiliphSpacing.lg),
            OutlinedButton(onPressed: onRestart, child: const Text('Done')),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(SiliphSpacing.sm),
      decoration: BoxDecoration(
        color: SiliphColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(SiliphRadii.md),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: SiliphColors.error, size: 20),
          const SizedBox(width: SiliphSpacing.sm),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
