/// Processing / PDF creation progress screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/siliph_colors.dart';
import '../../app/theme/siliph_spacing.dart';
import '../../app/theme/siliph_typography.dart';
import 'scan_mode.dart';
import 'scan_success_screen.dart';
import 'scanner_provider.dart';
import 'scanner_state.dart';

class ScanProcessingScreen extends ConsumerStatefulWidget {
  const ScanProcessingScreen({super.key, required this.mode});

  final ScanMode mode;

  @override
  ConsumerState<ScanProcessingScreen> createState() =>
      _ScanProcessingScreenState();
}

class _ScanProcessingScreenState extends ConsumerState<ScanProcessingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progress;
  String _currentStep = 'Preparing images...';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _progress = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _controller.forward();
    _simulateSteps();
  }

  Future<void> _simulateSteps() async {
    final steps = [
      (Duration(seconds: 500), 'Applying perspective correction...'),
      (Duration(seconds: 1000), 'Enhancing scan quality...'),
      (Duration(seconds: 1500), 'Creating your PDF...'),
      (Duration(seconds: 2200), 'Finalizing...'),
    ];

    for (final (delay, step) in steps) {
      await Future.delayed(delay);
      if (!mounted) return;
      setState(() => _currentStep = step);
    }

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    // Navigate to success
    final notifier = ref.read(scannerProvider(widget.mode).notifier);
    notifier.setPhase(ScanPhase.done);
    notifier.setProcessingProgress(1.0);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ScanSuccessScreen(mode: widget.mode),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scannerProvider(widget.mode));

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(SiliphSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated progress circle
              SizedBox(
                width: 100,
                height: 100,
                child: AnimatedBuilder(
                  animation: _progress,
                  builder: (context, child) {
                    return CircularProgressIndicator(
                      value: _progress.value,
                      strokeWidth: 6,
                      backgroundColor: SiliphColors.outline,
                      color: SiliphColors.categoryScanner,
                    );
                  },
                ),
              ),
              const SizedBox(height: SiliphSpacing.xl),
              Text(
                'Processing Scan',
                style: Theme.of(context).textTheme.headlineSmallStyle,
              ),
              const SizedBox(height: SiliphSpacing.sm),
              Text(
                _currentStep,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: SiliphColors.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: SiliphSpacing.md),
              Text(
                '${state.pageCount} ${state.pageCount == 1 ? 'page' : 'pages'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
