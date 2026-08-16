/// PDF Reader workflow (section 50 tool-screen standard).
///
/// Opens a PDF and renders it page by page on the native engine; pages
/// cross the bridge as JPEG preview bytes (app-generated payload, the one
/// honest exception to the URI-only rule).
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/siliph_colors.dart';
import '../../app/theme/siliph_spacing.dart';
import '../../app/theme/siliph_typography.dart';
import '../../domain/models/file_item.dart';
import '../../domain/providers.dart';
import '../../domain/services/native_bridge.dart';

enum _Phase { pick, reading }

class PdfReaderScreen extends ConsumerStatefulWidget {
  const PdfReaderScreen({super.key});

  @override
  ConsumerState<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends ConsumerState<PdfReaderScreen> {
  _Phase _phase = _Phase.pick;
  FileItem? _input;
  bool _busy = false;
  int _pageCount = 0;
  bool _encrypted = false;
  int _page = 0; // zero-based
  Uint8List? _bytes;
  bool _rendering = false;
  String? _error;
  TaskHandle? _activeRender;

  @override
  void dispose() {
    // Fire-and-forget cancellation of any in-flight render.
    final handle = _activeRender;
    if (handle != null) unawaited(handle.cancel().catchError((_) {}));
    super.dispose();
  }

  Future<void> _pick() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final picked = await ref
          .read(fileGatewayProvider)
          .openDocuments(const ['application/pdf']);
      if (picked.isEmpty || !mounted) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      final file = picked.first;
      final info = await ref.read(pdfGatewayProvider).inspect(file);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _input = file;
        _pageCount = info.pageCount;
        _encrypted = info.encrypted;
        _page = 0;
        _bytes = null;
        _phase = _Phase.reading;
      });
      unawaited(_render(0));
    } on BridgeException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.userMessage;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not open that PDF.';
      });
    }
  }

  Future<void> _render(int page) async {
    final input = _input;
    if (input == null) return;
    final handle = ref.read(pdfGatewayProvider).renderPage(
          input: input,
          pageIndex: page,
          dpi: 96,
        );
    _activeRender = handle;
    setState(() {
      _rendering = true;
      _error = null;
    });
    try {
      final bytes = await handle.image;
      await handle.done;
      if (!mounted || _page != page) return;
      setState(() {
        _bytes = bytes;
        _rendering = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (e is BridgeException && e.isCancelled) return;
      setState(() {
        _rendering = false;
        _error = e is BridgeException ? e.userMessage : 'Rendering failed.';
      });
    } finally {
      if (_activeRender == handle) _activeRender = null;
    }
  }

  void _go(int page) {
    if (page < 0 || page >= _pageCount || page == _page && _bytes != null) {
      return;
    }
    setState(() => _page = page);
    unawaited(_render(page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_input?.displayName ?? 'PDF Reader'),
        actions: [
          if (_phase == _Phase.reading)
            IconButton(
              tooltip: 'Open another PDF',
              icon: const Icon(Icons.folder_open_outlined),
              onPressed: _busy
                  ? null
                  : () => setState(() {
                        _phase = _Phase.pick;
                        _input = null;
                        _bytes = null;
                      }),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: switch (_phase) {
                _Phase.pick => _PickView(picking: _busy, onPick: _pick),
                _Phase.reading => _ReaderView(
                    encrypted: _encrypted,
                    pageCount: _pageCount,
                    page: _page,
                    bytes: _bytes,
                    rendering: _rendering,
                    onPrev: () => _go(_page - 1),
                    onNext: () => _go(_page + 1),
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
            const Icon(Icons.menu_book_outlined,
                size: 64, color: SiliphColors.primary),
            const SizedBox(height: SiliphSpacing.md),
            Text('PDF Reader',
                style: Theme.of(context).textTheme.headlineSmallStyle),
            const SizedBox(height: SiliphSpacing.xs),
            Text(
              'Open a PDF and read it page by page.',
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

class _ReaderView extends StatelessWidget {
  const _ReaderView({
    required this.encrypted,
    required this.pageCount,
    required this.page,
    required this.bytes,
    required this.rendering,
    required this.onPrev,
    required this.onNext,
  });

  final bool encrypted;
  final int pageCount;
  final int page;
  final Uint8List? bytes;
  final bool rendering;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4,
            child: Center(
              child: rendering || bytes == null
                  ? const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: SiliphSpacing.md),
                        Text('Rendering page…'),
                      ],
                    )
                  : Image.memory(bytes!, gaplessPlayback: true),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(SiliphSpacing.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Previous page',
                icon: const Icon(Icons.chevron_left),
                onPressed: page > 0 && !rendering ? onPrev : null,
              ),
              Text(
                'Page ${page + 1} of $pageCount',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              IconButton(
                tooltip: 'Next page',
                icon: const Icon(Icons.chevron_right),
                onPressed: page < pageCount - 1 && !rendering ? onNext : null,
              ),
            ],
          ),
        ),
        if (encrypted)
          Padding(
            padding: const EdgeInsets.only(
              left: SiliphSpacing.md,
              right: SiliphSpacing.md,
              bottom: SiliphSpacing.sm,
            ),
            child: Text(
              'This PDF is encrypted; pages may fail to render without '
              'being unlocked first.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
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
