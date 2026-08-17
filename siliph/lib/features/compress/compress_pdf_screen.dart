/// Compress PDF workflow matching the Siliph visual reference standard.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme/siliph_colors.dart';
import '../../app/theme/siliph_spacing.dart';
import '../../app/theme/siliph_typography.dart';
import '../../domain/models/file_item.dart';
import '../../domain/providers.dart';
import '../../domain/services/native_bridge.dart';
import '../../domain/services/pdf_plans.dart';
import '../../widgets/common/real_time_preview_card.dart';
import '../../widgets/common/siliph_processing_view.dart';
import '../../widgets/common/siliph_success_view.dart';

enum _Phase { pick, configure, compressing, done }

class CompressPdfScreen extends ConsumerStatefulWidget {
  const CompressPdfScreen({super.key});

  @override
  ConsumerState<CompressPdfScreen> createState() => _CompressPdfScreenState();
}

class _CompressPdfScreenState extends ConsumerState<CompressPdfScreen> {
  _Phase _phase = _Phase.pick;
  FileItem? _input;
  int _level = 1; // 0 = Low, 1 = Medium, 2 = High
  bool _picking = false;
  double _progress = 0;
  String? _error;
  FileItem? _output;
  StreamSubscription<double>? _progressSub;
  TaskHandle? _currentTask;

  // More options switches
  bool _removeUnusedObjects = true;
  bool _optimizeForWeb = false;
  bool _moreOptionsExpanded = false;

  @override
  void dispose() {
    final sub = _progressSub;
    _progressSub = null;
    if (sub != null) unawaited(sub.cancel());
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
      setState(() {
        _picking = false;
        if (picked.isNotEmpty) {
          _input = picked.first;
          _output = null;
          _phase = _Phase.configure;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _picking = false;
        _error = 'Could not open the file picker.';
      });
    }
  }

  Future<void> _compress() async {
    final input = _input;
    if (input == null) return;
    final output = await ref.read(fileGatewayProvider).createDocument(
          mimeType: 'application/pdf',
          displayName: '${stripPdfExtension(input.displayName)}-compressed.pdf',
        );
    if (!mounted) return;
    if (output == null) return;

    final handle = ref.read(pdfGatewayProvider).compress(
          input: input,
          level: _level,
          output: output,
        );
    _currentTask = handle;
    _progressSub = handle.progress.listen((value) {
      if (mounted) setState(() => _progress = value);
    });
    setState(() {
      _phase = _Phase.compressing;
      _progress = 0;
      _error = null;
    });
    try {
      await handle.done;
      if (!mounted) return;
      ref.read(importedFilesProvider.notifier).addAll([output]);
      setState(() {
        _output = output;
        _phase = _Phase.done;
      });
    } catch (e) {
      if (!mounted) return;
      if (e is BridgeException && e.isCancelled) return;
      setState(() {
        _phase = _Phase.configure;
        _error = e is BridgeException ? e.userMessage : 'Compression failed.';
      });
    } finally {
      final sub = _progressSub;
      _progressSub = null;
      if (sub != null) unawaited(sub.cancel());
      _currentTask = null;
    }
  }

  void _cancelCompression() {
    _currentTask?.cancel();
    setState(() {
      _phase = _Phase.configure;
      _progress = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final input = _input;
    final output = _output;

    return PopScope(
      canPop: _phase == _Phase.pick,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_phase == _Phase.configure || _phase == _Phase.done) {
          setState(() {
            _phase = _Phase.pick;
            _input = null;
            _output = null;
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Compress PDF'),
          leading: BackButton(
            onPressed: () {
              if (_phase == _Phase.configure || _phase == _Phase.done) {
                setState(() {
                  _phase = _Phase.pick;
                  _input = null;
                  _output = null;
                });
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: switch (_phase) {
                  _Phase.pick => _PickView(picking: _picking, onPick: _pick),
                  _Phase.configure => _ConfigureView(
                      file: input!,
                      level: _level,
                      removeUnusedObjects: _removeUnusedObjects,
                      optimizeForWeb: _optimizeForWeb,
                      moreOptionsExpanded: _moreOptionsExpanded,
                      onToggleMoreOptions: () => setState(
                        () => _moreOptionsExpanded = !_moreOptionsExpanded,
                      ),
                      onRemoveUnusedChanged: (val) =>
                          setState(() => _removeUnusedObjects = val),
                      onOptimizeWebChanged: (val) =>
                          setState(() => _optimizeForWeb = val),
                      onLevel: (value) => setState(() => _level = value),
                      onChangeFile: () => setState(() {
                        _phase = _Phase.pick;
                        _input = null;
                      }),
                      onCompress: _compress,
                    ),
                  _Phase.compressing => SiliphProcessingView(
                      title: 'Compressing PDF…',
                      progress: _progress,
                      onCancel: _cancelCompression,
                    ),
                  _Phase.done => SiliphSuccessView(
                      source: input!,
                      output: output!,
                      title: 'Compressed',
                      viewButtonLabel: 'View File',
                      onView: () {
                        context.push(
                          '${SiliphRoutes.pdfReaderWorkflow}?uri=${Uri.encodeComponent(output.uri)}',
                        );
                      },
                      onShare: () {
                        ref.read(fileGatewayProvider).share(output);
                      },
                      onDone: () => setState(() {
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SiliphSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF2A2838)
                    : SiliphColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.compress,
                size: 40,
                color: isDark ? const Color(0xFF8C70FF) : SiliphColors.primary,
              ),
            ),
            const SizedBox(height: SiliphSpacing.lg),
            Text(
              'Compress PDF',
              style: theme.textTheme.headlineSmallStyle.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: SiliphSpacing.xs),
            Text(
              'Shrink file size with real-time compression preview.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMediumStyle.copyWith(
                color: isDark ? const Color(0xFF9E9AA8) : SiliphColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: SiliphSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: picking ? null : onPick,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: SiliphSpacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(SiliphRadii.md),
                  ),
                ),
                icon: picking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.picture_as_pdf_outlined),
                label: Text(
                  picking ? 'Opening…' : 'Choose PDF',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
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
    required this.level,
    required this.removeUnusedObjects,
    required this.optimizeForWeb,
    required this.moreOptionsExpanded,
    required this.onToggleMoreOptions,
    required this.onRemoveUnusedChanged,
    required this.onOptimizeWebChanged,
    required this.onLevel,
    required this.onChangeFile,
    required this.onCompress,
  });

  final FileItem file;
  final int level;
  final bool removeUnusedObjects;
  final bool optimizeForWeb;
  final bool moreOptionsExpanded;
  final VoidCallback onToggleMoreOptions;
  final ValueChanged<bool> onRemoveUnusedChanged;
  final ValueChanged<bool> onOptimizeWebChanged;
  final ValueChanged<int> onLevel;
  final VoidCallback onChangeFile;
  final VoidCallback onCompress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Calculate real-time estimated size based on compression level
    final originalBytes = file.sizeBytes > 0 ? file.sizeBytes : 2400000;
    final (ratio, percentSaved, qualityTitle, qualityDesc) = switch (level) {
      0 => (0.70, 30, 'High Quality', 'Light compression with highest fidelity'),
      1 => (0.46, 54, 'Good', 'Balanced quality and file size'),
      _ => (0.28, 72, 'Maximum', 'Smallest file size for fast sharing'),
    };
    final estimatedBytes = (originalBytes * ratio).toInt();
    final estimatedSizeFormatted = '~${_formatBytes(estimatedBytes)}';
    final originalSizeFormatted = file.formattedSize.isNotEmpty
        ? file.formattedSize
        : _formatBytes(originalBytes);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(SiliphSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. File Info Card
          Container(
            padding: const EdgeInsets.all(SiliphSpacing.sm),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1C26) : const Color(0xFFF9F8FD),
              borderRadius: BorderRadius.circular(SiliphRadii.md),
              border: Border.all(
                color: isDark ? const Color(0xFF2E2C3A) : SiliphColors.outline,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5484D).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(SiliphRadii.sm),
                  ),
                  child: const Icon(
                    Icons.picture_as_pdf,
                    color: Color(0xFFE5484D),
                    size: 20,
                  ),
                ),
                const SizedBox(width: SiliphSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.displayName,
                        style: theme.textTheme.titleSmallStyle.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        file.formattedSize.isEmpty ? 'PDF Document' : file.formattedSize,
                        style: theme.textTheme.bodySmallStyle.copyWith(
                          color: isDark
                              ? const Color(0xFF9E9AA8)
                              : SiliphColors.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 18,
                    color: isDark ? const Color(0xFF9E9AA8) : SiliphColors.onSurfaceVariant,
                  ),
                  tooltip: 'Choose another file',
                  onPressed: onChangeFile,
                ),
              ],
            ),
          ),
          const SizedBox(height: SiliphSpacing.sm),

          // 2. Real-time Compression Preview Header & Mockup
          Text(
            'Real-time Compression Preview',
            style: theme.textTheme.titleSmallStyle.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),

          PdfDocumentComparisonPreview(
            originalSize: originalSizeFormatted,
            estimatedSize: estimatedSizeFormatted,
            percentSaved: percentSaved,
          ),
          const SizedBox(height: 4),

          // Real-time Metrics Card
          RealTimeMetricsCard(
            originalSizeFormatted: originalSizeFormatted,
            estimatedSizeFormatted: estimatedSizeFormatted,
            percentSaved: percentSaved,
            estimatedQuality: qualityTitle,
            qualityDescription: qualityDesc,
            showQualityFooter: false,
          ),
          const SizedBox(height: 2),
          Text(
            'Pages are re-rendered: text in the output will not be selectable.',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? const Color(0xFF9E9AA8) : SiliphColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: SiliphSpacing.sm),

          // 3. Compression Level Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Compression Level',
                style: theme.textTheme.titleSmallStyle.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              Text(
                level == 0 ? 'Low' : (level == 1 ? 'Medium' : 'High'),
                style: TextStyle(
                  color: isDark ? const Color(0xFF8C70FF) : SiliphColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),

          // Slider & Labels
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: isDark ? const Color(0xFF8C70FF) : SiliphColors.primary,
              thumbColor: isDark ? const Color(0xFF8C70FF) : SiliphColors.primary,
              inactiveTrackColor: isDark ? const Color(0xFF2E2C3A) : const Color(0xFFE2DEF0),
            ),
            child: Slider(
              value: level.toDouble(),
              min: 0,
              max: 2,
              divisions: 2,
              onChanged: (val) => onLevel(val.round()),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLevelLabel('Low', 'Best quality', level == 0, 0, isDark),
              _buildLevelLabel('Medium', 'Balanced', level == 1, 1, isDark),
              _buildLevelLabel('High', 'Smallest size', level == 2, 2, isDark),
            ],
          ),
          const SizedBox(height: SiliphSpacing.sm),

          // 4. More Options (Accordion / Switches)
          InkWell(
            onTap: onToggleMoreOptions,
            borderRadius: BorderRadius.circular(SiliphRadii.md),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'More Options',
                    style: theme.textTheme.titleSmallStyle.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  Icon(
                    moreOptionsExpanded ? Icons.expand_less : Icons.expand_more,
                    color: isDark ? const Color(0xFF9E9AA8) : SiliphColors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (moreOptionsExpanded) ...[
            SwitchListTile(
              title: const Text('Remove unused objects', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: Text(
                'Remove unused data and fonts',
                style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF9E9AA8) : SiliphColors.onSurfaceVariant),
              ),
              value: removeUnusedObjects,
              activeTrackColor: isDark ? const Color(0xFF8C70FF) : SiliphColors.primary,
              contentPadding: EdgeInsets.zero,
              onChanged: onRemoveUnusedChanged,
            ),
            SwitchListTile(
              title: const Text('Optimize for web', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: Text(
                'Fast web view',
                style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF9E9AA8) : SiliphColors.onSurfaceVariant),
              ),
              value: optimizeForWeb,
              activeTrackColor: isDark ? const Color(0xFF8C70FF) : SiliphColors.primary,
              contentPadding: EdgeInsets.zero,
              onChanged: onOptimizeWebChanged,
            ),
          ],
          const SizedBox(height: SiliphSpacing.md),

          // 5. Final CTA Button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onCompress,
              style: FilledButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF8C70FF) : SiliphColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: SiliphSpacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(SiliphRadii.md),
                ),
              ),
              child: const Text(
                'Save compressed PDF',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: SiliphSpacing.sm),
        ],
      ),
    );
  }

  Widget _buildLevelLabel(String title, String subtitle, bool isSelected, int levelValue, bool isDark) {
    return InkWell(
      onTap: () => onLevel(levelValue),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? (isDark ? const Color(0xFF8C70FF) : SiliphColors.primary)
                    : (isDark ? const Color(0xFF757082) : const Color(0xFF9E9AA8)),
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? const Color(0xFF757082) : const Color(0xFFA6A2B3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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
