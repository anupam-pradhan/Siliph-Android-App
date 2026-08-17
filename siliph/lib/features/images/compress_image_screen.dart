/// Compress Image workflow matching the Siliph visual reference standard.
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
import '../../widgets/common/real_time_preview_card.dart';
import '../../widgets/common/siliph_processing_view.dart';
import '../../widgets/common/siliph_success_view.dart';

enum _Phase { pick, configure, compressing, done }

class CompressImageScreen extends ConsumerStatefulWidget {
  const CompressImageScreen({super.key});

  @override
  ConsumerState<CompressImageScreen> createState() =>
      _CompressImageScreenState();
}

class _CompressImageScreenState extends ConsumerState<CompressImageScreen> {
  _Phase _phase = _Phase.pick;
  FileItem? _input;
  bool _picking = false;
  double _progress = 0;
  String? _error;
  FileItem? _output;
  String _format = 'jpeg';
  double _quality = 70; // Default 70%
  StreamSubscription<double>? _progressSub;
  TaskHandle? _currentTask;

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
      final picked = await ref.read(fileGatewayProvider).openDocuments(const [
        'image/*',
      ]);
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

  Future<void> _run() async {
    final input = _input;
    if (input == null) return;
    final ext = _format == 'webp' ? 'webp' : 'jpg';
    final mime = _format == 'webp' ? 'image/webp' : 'image/jpeg';
    final output = await ref.read(fileGatewayProvider).createDocument(
          mimeType: mime,
          displayName: '${baseName(input)}-compressed.$ext',
        );
    if (!mounted) return;
    if (output == null) return;

    final handle = ref.read(imageToolsGatewayProvider).compress(
          input: input,
          format: _format,
          quality: _quality.round(),
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
          title: const Text('Compress Image'),
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
                      format: _format,
                      quality: _quality,
                      onFormatChanged: (val) => setState(() => _format = val),
                      onQualityChanged: (val) => setState(() => _quality = val),
                      onChangeFile: () => setState(() {
                        _phase = _Phase.pick;
                        _input = null;
                      }),
                      onCompress: _run,
                    ),
                  _Phase.compressing => SiliphProcessingView(
                      title: 'Compressing Image…',
                      subtitle: "Please don't close the app",
                      progress: _progress,
                      onCancel: _cancelCompression,
                      customSteps: const [
                        'Preparing image',
                        'Analyzing image',
                        'Compressing',
                        'Optimizing',
                        'Finalizing',
                      ],
                    ),
                  _Phase.done => SiliphSuccessView(
                      source: input!,
                      output: output!,
                      title: 'Image compressed',
                      subtitle: 'Your image has been compressed.',
                      viewButtonLabel: 'View Image',
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
                Icons.photo_size_select_small,
                size: 40,
                color: isDark ? const Color(0xFF8C70FF) : SiliphColors.primary,
              ),
            ),
            const SizedBox(height: SiliphSpacing.lg),
            Text(
              'Compress Image',
              style: theme.textTheme.headlineSmallStyle.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: SiliphSpacing.xs),
            Text(
              'Shrink photos and pictures with live before/after preview.',
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
                    : const Icon(Icons.image_outlined),
                label: Text(
                  picking ? 'Opening…' : 'Choose image',
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
    required this.format,
    required this.quality,
    required this.onFormatChanged,
    required this.onQualityChanged,
    required this.onChangeFile,
    required this.onCompress,
  });

  final FileItem file;
  final String format;
  final double quality;
  final ValueChanged<String> onFormatChanged;
  final ValueChanged<double> onQualityChanged;
  final VoidCallback onChangeFile;
  final VoidCallback onCompress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Calculate real-time estimated size based on quality
    final originalBytes = file.sizeBytes > 0 ? file.sizeBytes : 2800000;
    // Scale estimation factor from 0.25 (at quality 20) to 0.75 (at quality 90)
    final qualityFraction = (quality / 100.0).clamp(0.20, 0.95);
    final ratio = 0.20 + (qualityFraction * 0.65);
    final estimatedBytes = (originalBytes * ratio).toInt();
    final percentSaved = (((originalBytes - estimatedBytes) / originalBytes) * 100).round();
    final estimatedSizeFormatted = '~${_formatBytes(estimatedBytes)}';
    final originalSizeFormatted = file.formattedSize.isNotEmpty
        ? file.formattedSize
        : _formatBytes(originalBytes);

    final qualityLabel = quality <= 35
        ? 'Low'
        : (quality <= 70 ? 'Medium' : 'High');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(SiliphSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        // 1. File Card
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
                  color: const Color(0xFF3E9BFF).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(SiliphRadii.sm),
                ),
                child: const Icon(
                  Icons.image,
                  color: Color(0xFF3E9BFF),
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
                      '${file.formattedSize.isEmpty ? "Image" : file.formattedSize} • 4000 × 3000',
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
                tooltip: 'Choose another image',
                onPressed: onChangeFile,
              ),
            ],
          ),
        ),
        const SizedBox(height: SiliphSpacing.sm),

        // 2. Real-time Compression Preview Header & Visual Split/Before-After
        Text(
          'Real-time Compression Preview',
          style: theme.textTheme.titleSmallStyle.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 4),

        // Visual Before/After mockup container
        Container(
          height: 80,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1C26) : const Color(0xFFE8E5F2),
            borderRadius: BorderRadius.circular(SiliphRadii.md),
            border: Border.all(
              color: isDark ? const Color(0xFF2E2C3A) : SiliphColors.outline,
            ),
          ),
          child: Row(
            children: [
              // Before
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF3A4060), Color(0xFF1E2235)],
                        ),
                        borderRadius: BorderRadius.horizontal(
                          left: Radius.circular(SiliphRadii.md),
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.landscape,
                          size: 32,
                          color: Color(0xFF7A87B2),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text(
                          'Before',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 4,
                      left: 6,
                      child: Text(
                        '4000 × 3000',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Split Divider
              Container(width: 1, color: isDark ? const Color(0xFF3E3A52) : Colors.white),

              // After
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF2C324E), Color(0xFF171A29)],
                        ),
                        borderRadius: BorderRadius.horizontal(
                          right: Radius.circular(SiliphRadii.md),
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.landscape,
                          size: 32,
                          color: Color(0xFF5A668E),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1F9D55).withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text(
                          'After',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 4,
                      right: 6,
                      child: Text(
                        '4000 × 3000',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: SiliphSpacing.xs),

        // Real-time Metrics Card
        RealTimeMetricsCard(
          originalSizeFormatted: originalSizeFormatted,
          estimatedSizeFormatted: estimatedSizeFormatted,
          percentSaved: percentSaved,
          showQualityFooter: false,
        ),
        const SizedBox(height: SiliphSpacing.sm),

        // 3. Compression Quality Slider
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Compression Quality',
              style: theme.textTheme.titleSmallStyle.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            Text(
              qualityLabel,
              style: TextStyle(
                color: isDark ? const Color(0xFF8C70FF) : SiliphColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),

        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: isDark ? const Color(0xFF8C70FF) : SiliphColors.primary,
            thumbColor: isDark ? const Color(0xFF8C70FF) : SiliphColors.primary,
            inactiveTrackColor: isDark ? const Color(0xFF2E2C3A) : const Color(0xFFE2DEF0),
          ),
          child: Slider(
            value: quality,
            min: 20,
            max: 90,
            divisions: 7,
            onChanged: onQualityChanged,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildQualityLabel('Low', '20%', quality <= 35, isDark),
            _buildQualityLabel('Medium', '60%', quality > 35 && quality <= 70, isDark),
            _buildQualityLabel('High', '90%', quality > 70, isDark),
          ],
        ),
        const SizedBox(height: SiliphSpacing.sm),

        // 4. Output Format
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Output Format',
              style: theme.textTheme.titleSmallStyle.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'jpeg', label: Text('JPG')),
                ButtonSegment(value: 'png', label: Text('PNG')),
                ButtonSegment(value: 'webp', label: Text('WebP')),
              ],
              selected: {format},
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor:
                    isDark ? const Color(0xFF8C70FF) : SiliphColors.primary,
                selectedForegroundColor: Colors.white,
              ),
              onSelectionChanged: (set) => onFormatChanged(set.first),
            ),
          ],
        ),
        const SizedBox(height: SiliphSpacing.md),

        // 5. Final Action Button
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
              'Save compressed image',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: SiliphSpacing.sm),
      ],
    ),
  );
  }

  Widget _buildQualityLabel(String title, String percent, bool isSelected, bool isDark) {
    return Column(
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
          percent,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? const Color(0xFF757082) : const Color(0xFFA6A2B3),
          ),
        ),
      ],
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
