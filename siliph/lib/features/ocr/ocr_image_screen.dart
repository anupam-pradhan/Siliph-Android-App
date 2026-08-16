/// OCR (image) workflow: extract text from a photo or picked image
/// (section 50 tool-screen standard). Recognition runs fully on-device.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/siliph_colors.dart';
import '../../app/theme/siliph_spacing.dart';
import '../../app/theme/siliph_typography.dart';
import '../../domain/models/file_item.dart';
import '../../domain/providers.dart';
import '../../domain/services/native_bridge.dart';
import '../../generated/siliph_bridge.g.dart';

enum _Phase { pick, running, done }

class OcrImageScreen extends ConsumerStatefulWidget {
  const OcrImageScreen({super.key});

  @override
  ConsumerState<OcrImageScreen> createState() => _OcrImageScreenState();
}

class _OcrImageScreenState extends ConsumerState<OcrImageScreen> {
  _Phase _phase = _Phase.pick;
  bool _busy = false;
  List<OcrBlock> _blocks = const [];
  String? _error;
  String? _notice;

  Future<void> _fromCamera() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final shot = await ref.read(fileGatewayProvider).takePhoto();
      if (!mounted) return;
      setState(() => _busy = false);
      if (shot != null) unawaited(_recognize(shot));
    } on BridgeException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.userMessage;
      });
    }
  }

  Future<void> _fromGallery() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final picked = await ref.read(fileGatewayProvider).pickImages(maxItems: 1);
      if (!mounted) return;
      setState(() => _busy = false);
      if (picked.isNotEmpty) unawaited(_recognize(picked.first));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not open the image picker.';
      });
    }
  }

  Future<void> _recognize(FileItem image) async {
    final handle = ref.read(ocrGatewayProvider).recognizeImage(image: image);
    setState(() {
      _phase = _Phase.running;
      _error = null;
    });
    try {
      final blocks = await handle.ocrBlocks;
      await handle.done;
      if (!mounted) return;
      setState(() {
        _blocks = blocks ?? const [];
        _phase = _Phase.done;
      });
    } catch (e) {
      if (!mounted) return;
      if (e is BridgeException && e.isCancelled) return;
      setState(() {
        _phase = _Phase.pick;
        _error = e is BridgeException ? e.userMessage : 'Recognition failed.';
      });
    }
  }

  Future<void> _copyAll() async {
    final text = _blocks.map((b) => b.text).join('\n\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    setState(() => _notice = 'All text copied to clipboard.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OCR — Image')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: switch (_phase) {
                _Phase.pick => _PickView(
                    busy: _busy,
                    onCamera: _fromCamera,
                    onGallery: _fromGallery,
                  ),
                _Phase.running => const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: SiliphSpacing.md),
                        Text('Recognizing text…'),
                      ],
                    ),
                  ),
                _Phase.done => _ResultView(
                    blocks: _blocks,
                    notice: _notice,
                    onCopyAll: _copyAll,
                    onRestart: () => setState(() {
                          _phase = _Phase.pick;
                          _blocks = const [];
                          _notice = null;
                          _error = null;
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
  const _PickView({
    required this.busy,
    required this.onCamera,
    required this.onGallery,
  });

  final bool busy;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SiliphSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.text_fields_outlined,
                size: 64, color: SiliphColors.primary),
            const SizedBox(height: SiliphSpacing.md),
            Text('Extract text from an image',
                style: Theme.of(context).textTheme.headlineSmallStyle),
            const SizedBox(height: SiliphSpacing.xs),
            Text(
              'Recognition runs on this device; nothing is uploaded.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: SiliphSpacing.lg),
            FilledButton.icon(
              onPressed: busy ? null : onCamera,
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Take photo'),
            ),
            const SizedBox(height: SiliphSpacing.sm),
            OutlinedButton.icon(
              onPressed: busy ? null : onGallery,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Choose image'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.blocks,
    required this.notice,
    required this.onCopyAll,
    required this.onRestart,
  });

  final List<OcrBlock> blocks;
  final String? notice;
  final VoidCallback onCopyAll;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(SiliphSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  blocks.isEmpty
                      ? 'No text recognized'
                      : 'Recognized ${blocks.length} '
                          '${blocks.length == 1 ? 'block' : 'blocks'}',
                  style: Theme.of(context).textTheme.titleMediumStyle,
                ),
              ),
              TextButton.icon(
                onPressed: blocks.isEmpty ? null : onCopyAll,
                icon: const Icon(Icons.copy_all_outlined, size: 18),
                label: const Text('Copy all'),
              ),
            ],
          ),
          if (notice != null)
            Padding(
              padding: const EdgeInsets.only(bottom: SiliphSpacing.xs),
              child: Text(notice!, style: Theme.of(context).textTheme.bodySmall),
            ),
          Expanded(
            child: blocks.isEmpty
                ? Center(
                    child: Text(
                      'Try a sharper, better-lit photo with the text '
                      'filling the frame.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                : ListView.separated(
                    itemCount: blocks.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: SiliphSpacing.xs),
                    itemBuilder: (context, index) {
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(SiliphSpacing.sm),
                          child: SelectableText(
                            blocks[index].text,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: SiliphSpacing.sm),
          OutlinedButton(onPressed: onRestart, child: const Text('Scan another')),
        ],
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
