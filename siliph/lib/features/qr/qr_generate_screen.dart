/// QR Generator workflow (section 50 tool-screen standard).
///
/// Encodes text as a QR code PNG on the native side (no third-party
/// dependency; see docs/reuse-records.md Record 7). The output is saved
/// through the SAF save-as dialog at 10 px per module.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/siliph_colors.dart';
import '../../app/theme/siliph_spacing.dart';
import '../../app/theme/siliph_typography.dart';
import '../../domain/models/file_item.dart';
import '../../domain/providers.dart';
import '../../domain/services/native_bridge.dart';

enum _Phase { compose, saving, done }

class QrGenerateScreen extends ConsumerStatefulWidget {
  const QrGenerateScreen({super.key});

  @override
  ConsumerState<QrGenerateScreen> createState() => _QrGenerateScreenState();
}

class _QrGenerateScreenState extends ConsumerState<QrGenerateScreen> {
  final TextEditingController _content = TextEditingController();
  _Phase _phase = _Phase.compose;
  int _ecLevel = 1; // Medium.
  String? _error;
  FileItem? _output;

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  bool get _hasContent => _content.text.trim().isNotEmpty;

  Future<void> _save() async {
    if (!_hasContent) return;
    setState(() {
      _phase = _Phase.saving;
      _error = null;
    });
    try {
      final output = await ref.read(fileGatewayProvider).createDocument(
            mimeType: 'image/png',
            displayName: 'qrcode.png',
          );
      if (!mounted) return;
      if (output == null) {
        setState(() => _phase = _Phase.compose);
        return; // User cancelled the save dialog.
      }
      await ref.read(fileToolsGatewayProvider).generateQr(
            content: _content.text.trim(),
            ecLevel: _ecLevel,
            output: output,
          );
      if (!mounted) return;
      setState(() {
        _output = output;
        _phase = _Phase.done;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.compose;
        _error = e is BridgeException ? e.userMessage : 'QR generation failed.';
      });
    }
  }

  void _restart() {
    setState(() {
      _phase = _Phase.compose;
      _output = null;
      _content.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR Generator')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: switch (_phase) {
                _Phase.compose => _ComposeView(
                    controller: _content,
                    ecLevel: _ecLevel,
                    hasContent: _hasContent,
                    onChanged: (_) => setState(() {}),
                    onEcLevel: (value) => setState(() => _ecLevel = value),
                    onSave: _save,
                  ),
                _Phase.saving => const Center(
                    child: CircularProgressIndicator(),
                  ),
                _Phase.done => _DoneView(
                    name: _output?.displayName ?? 'qrcode.png',
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

class _ComposeView extends StatelessWidget {
  const _ComposeView({
    required this.controller,
    required this.ecLevel,
    required this.hasContent,
    required this.onChanged,
    required this.onEcLevel,
    required this.onSave,
  });

  final TextEditingController controller;
  final int ecLevel;
  final bool hasContent;
  final ValueChanged<String> onChanged;
  final ValueChanged<int> onEcLevel;
  final VoidCallback onSave;

  static const _ecHints = [
    'Low — recovers about 7% damage',
    'Medium — recovers about 15% damage',
    'Quartile — recovers about 25% damage',
    'High — recovers about 30% damage',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(SiliphSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Content', style: Theme.of(context).textTheme.titleMediumStyle),
          const SizedBox(height: SiliphSpacing.xs),
          TextField(
            controller: controller,
            onChanged: onChanged,
            maxLines: 4,
            maxLength: 1000,
            decoration: const InputDecoration(
              hintText: 'Link, text or Wi-Fi details…',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: SiliphSpacing.md),
          Text('Error correction',
              style: Theme.of(context).textTheme.titleMediumStyle),
          const SizedBox(height: SiliphSpacing.xs),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Low')),
              ButtonSegment(value: 1, label: Text('Medium')),
              ButtonSegment(value: 2, label: Text('Quartile')),
              ButtonSegment(value: 3, label: Text('High')),
            ],
            selected: {ecLevel},
            onSelectionChanged: (selection) => onEcLevel(selection.first),
          ),
          const SizedBox(height: SiliphSpacing.xs),
          Text(_ecHints[ecLevel],
              style: Theme.of(context).textTheme.bodySmall),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: hasContent ? onSave : null,
              icon: const Icon(Icons.qr_code_2_outlined),
              label: Text(hasContent ? 'Save PNG' : 'Enter content first'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DoneView extends StatelessWidget {
  const _DoneView({required this.name, required this.onRestart});

  final String name;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SiliphSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle,
                size: 64, color: SiliphColors.success),
            const SizedBox(height: SiliphSpacing.md),
            Text('QR code saved',
                style: Theme.of(context).textTheme.headlineSmallStyle),
            const SizedBox(height: SiliphSpacing.xs),
            Text(
              'Saved as "$name".',
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
