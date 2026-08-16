/// Sign PDF workflow: stamp a signature image onto one page of a PDF
/// (section 50 tool-screen standard).
///
/// The signature is placed as a new image object on top of the page
/// (original content untouched); position and size are chosen with
/// sliders against a schematic page preview.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/siliph_colors.dart';
import '../../app/theme/siliph_spacing.dart';
import '../../app/theme/siliph_typography.dart';
import '../../domain/models/file_item.dart';
import '../../domain/providers.dart';
import '../../domain/services/file_facts.dart';
import '../../domain/services/native_bridge.dart';

enum _Phase { pick, configure, running, done }

class SignPdfScreen extends ConsumerStatefulWidget {
  const SignPdfScreen({super.key});

  @override
  ConsumerState<SignPdfScreen> createState() => _SignPdfScreenState();
}

class _SignPdfScreenState extends ConsumerState<SignPdfScreen> {
  _Phase _phase = _Phase.pick;
  FileItem? _input;
  FileItem? _signature;
  bool _picking = false;
  int _pageCount = 0;
  int _pageNumber = 1; // one-based
  double _x = 0.55;
  double _y = 0.8;
  double _width = 0.3;
  FileItem? _output;
  String? _error;

  Future<void> _pickPdf() async {
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final picked = await ref
          .read(fileGatewayProvider)
          .openDocuments(const ['application/pdf']);
      if (picked.isEmpty || !mounted) {
        if (mounted) setState(() => _picking = false);
        return;
      }
      final info = await ref.read(pdfGatewayProvider).inspect(picked.first);
      if (!mounted) return;
      setState(() {
        _picking = false;
        _input = picked.first;
        _pageCount = info.pageCount;
        _pageNumber = info.pageCount.clamp(1, info.pageCount);
        _phase = _Phase.configure;
      });
    } on BridgeException catch (e) {
      if (!mounted) return;
      setState(() {
        _picking = false;
        _error = e.userMessage;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _picking = false;
        _error = 'Could not open the file picker.';
      });
    }
  }

  Future<void> _pickSignature() async {
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final picked = await ref.read(fileGatewayProvider).pickImages(maxItems: 1);
      if (!mounted) return;
      setState(() {
        _picking = false;
        if (picked.isNotEmpty) _signature = picked.first;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _picking = false;
        _error = 'Could not open the image picker.';
      });
    }
  }

  Future<void> _sign() async {
    final input = _input;
    final signature = _signature;
    if (input == null || signature == null) return;
    setState(() {
      _phase = _Phase.running;
      _error = null;
    });
    try {
      final output = await ref.read(fileGatewayProvider).createDocument(
            mimeType: 'application/pdf',
            displayName: '${baseName(input)}-signed.pdf',
          );
      if (!mounted) return;
      if (output == null) {
        setState(() => _phase = _Phase.configure);
        return;
      }
      final handle = ref.read(pdfGatewayProvider).stampImage(
            input: input,
            image: signature,
            pageNumber: _pageNumber,
            x: _x,
            y: _y,
            widthFraction: _width,
            output: output,
          );
      await handle.done;
      if (!mounted) return;
      setState(() {
        _output = output;
        _phase = _Phase.done;
      });
    } catch (e) {
      if (!mounted) return;
      if (e is BridgeException && e.isCancelled) return;
      setState(() {
        _phase = _Phase.configure;
        _error = e is BridgeException ? e.userMessage : 'Signing failed.';
      });
    }
  }

  Future<void> _share() async {
    final output = _output;
    if (output == null) return;
    try {
      await ref.read(fileGatewayProvider).share(output);
    } on BridgeException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.userMessage);
    }
  }

  void _restart() {
    setState(() {
      _phase = _Phase.pick;
      _input = null;
      _signature = null;
      _output = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign PDF')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: switch (_phase) {
                _Phase.pick => _PickView(picking: _picking, onPick: _pickPdf),
                _Phase.configure => _ConfigureView(
                    file: _input!,
                    signature: _signature,
                    pageCount: _pageCount,
                    pageNumber: _pageNumber,
                    x: _x,
                    y: _y,
                    width: _width,
                    busy: _picking,
                    onPickSignature: _pickSignature,
                    onPage: (value) => setState(() => _pageNumber = value),
                    onX: (value) => setState(() => _x = value),
                    onY: (value) => setState(() => _y = value),
                    onWidth: (value) => setState(() => _width = value),
                    onSign: _sign,
                  ),
                _Phase.running => const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: SiliphSpacing.md),
                        Text('Stamping signature…'),
                      ],
                    ),
                  ),
                _Phase.done => _DoneView(
                    name: _output?.displayName ?? 'signed.pdf',
                    onShare: _share,
                    onRestart: _restart,
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
            const Icon(Icons.draw_outlined,
                size: 64, color: SiliphColors.primary),
            const SizedBox(height: SiliphSpacing.md),
            Text('Add a signature to a PDF',
                style: Theme.of(context).textTheme.headlineSmallStyle),
            const SizedBox(height: SiliphSpacing.xs),
            Text(
              'Stamp a signature image (PNG with transparency works best) '
              'onto one page. Draw one first with the Signature Maker.',
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

class _ConfigureView extends StatelessWidget {
  const _ConfigureView({
    required this.file,
    required this.signature,
    required this.pageCount,
    required this.pageNumber,
    required this.x,
    required this.y,
    required this.width,
    required this.busy,
    required this.onPickSignature,
    required this.onPage,
    required this.onX,
    required this.onY,
    required this.onWidth,
    required this.onSign,
  });

  final FileItem file;
  final FileItem? signature;
  final int pageCount;
  final int pageNumber;
  final double x;
  final double y;
  final double width;
  final bool busy;
  final VoidCallback onPickSignature;
  final ValueChanged<int> onPage;
  final ValueChanged<double> onX;
  final ValueChanged<double> onY;
  final ValueChanged<double> onWidth;
  final VoidCallback onSign;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(SiliphSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(SiliphSpacing.md),
              child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf_outlined,
                      color: SiliphColors.primary),
                  const SizedBox(width: SiliphSpacing.sm),
                  Expanded(
                    child: Text(file.displayName,
                        style: Theme.of(context).textTheme.titleMediumStyle),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: SiliphSpacing.md),
          Text('Signature image',
              style: Theme.of(context).textTheme.titleMediumStyle),
          const SizedBox(height: SiliphSpacing.xs),
          Card(
            child: InkWell(
              onTap: busy ? null : onPickSignature,
              borderRadius: BorderRadius.circular(SiliphRadii.lg),
              child: Padding(
                padding: const EdgeInsets.all(SiliphSpacing.md),
                child: Row(
                  children: [
                    const Icon(Icons.draw_outlined,
                        color: SiliphColors.primary),
                    const SizedBox(width: SiliphSpacing.sm),
                    Expanded(
                      child: Text(
                        signature?.displayName ?? 'Tap to choose a signature image',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: SiliphSpacing.md),
          if (pageCount > 1) ...[
            Text('Page: $pageNumber of $pageCount',
                style: Theme.of(context).textTheme.titleMediumStyle),
            Slider(
              value: pageNumber.toDouble(),
              min: 1,
              max: pageCount.toDouble(),
              divisions: pageCount - 1,
              onChanged: (value) => onPage(value.round()),
            ),
          ],
          const SizedBox(height: SiliphSpacing.sm),
          _PlacementPreview(x: x, y: y, width: width),
          Text('Horizontal position',
              style: Theme.of(context).textTheme.bodySmall),
          Slider(value: x, onChanged: onX),
          Text('Vertical position',
              style: Theme.of(context).textTheme.bodySmall),
          Slider(value: y, onChanged: onY),
          Text('Size', style: Theme.of(context).textTheme.bodySmall),
          Slider(
            value: width,
            min: 0.05,
            max: 0.8,
            onChanged: onWidth,
          ),
          const SizedBox(height: SiliphSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: signature == null || busy ? null : onSign,
              icon: const Icon(Icons.draw_outlined),
              label: Text(
                signature == null ? 'Choose a signature image' : 'Sign PDF',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Schematic page showing where the stamp will land. The height follows
/// a typical portrait page; the stamp height is drawn from a fixed 1:3
/// aspect because the image's own dimensions are not readable in Dart.
class _PlacementPreview extends StatelessWidget {
  const _PlacementPreview({
    required this.x,
    required this.y,
    required this.width,
  });

  final double x;
  final double y;
  final double width;

  @override
  Widget build(BuildContext context) {
    const stampAspect = 1 / 3;
    const pageWidth = 160.0;
    const pageHeight = 220.0;
    final w = width * pageWidth;
    final h = (w * stampAspect).clamp(4.0, pageHeight);
    final left = (x * pageWidth).clamp(0.0, pageWidth - w);
    final top = (y * pageHeight).clamp(0.0, pageHeight - h);
    return Center(
      child: SizedBox(
        width: pageWidth,
        height: pageHeight,
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  border: Border.all(color: SiliphColors.primary),
                  borderRadius: BorderRadius.circular(SiliphRadii.md),
                ),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              width: w,
              height: h,
              child: Container(
                decoration: BoxDecoration(
                  color: SiliphColors.primary.withValues(alpha: 0.35),
                  border: Border.all(color: SiliphColors.primary),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DoneView extends StatelessWidget {
  const _DoneView({
    required this.name,
    required this.onShare,
    required this.onRestart,
  });

  final String name;
  final VoidCallback onShare;
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
            Text('Signature added',
                style: Theme.of(context).textTheme.headlineSmallStyle),
            const SizedBox(height: SiliphSpacing.xs),
            Text(
              '"$name" is ready. The signature is a visible image stamp, '
              'not a cryptographic signature.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: SiliphSpacing.lg),
            FilledButton.icon(
              onPressed: onShare,
              icon: const Icon(Icons.share_outlined),
              label: const Text('Share PDF'),
            ),
            const SizedBox(height: SiliphSpacing.sm),
            OutlinedButton(onPressed: onRestart, child: const Text('Sign another')),
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
