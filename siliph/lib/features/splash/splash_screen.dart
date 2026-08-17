/// Siliph Branded Splash Screen (section 5).
///
/// Sequence:
///   1. Purple/violet brand glow appears softly.
///   2. High-res Siliph logo mark scales in with smooth ease-out.
///   3. Subtitle "Private. Fast. On your device." fades in.
///   4. Subtle light shimmer passes over the mark.
///   5. Seamless transition to Home (1.5s max; instant on reduced motion).
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme/siliph_colors.dart';
import '../../app/theme/siliph_spacing.dart';
import '../../app/theme/siliph_typography.dart';
import '../settings/settings_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _glowAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;
  late final Animation<double> _shimmerAnimation;
  Timer? _navTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _glowAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.easeInOut),
      ),
    );

    // Check reduced motion setting
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final reducedMotion = ref.read(settingsProvider).reducedMotion;
      if (reducedMotion) {
        // Fast transition for accessibility
        _navTimer = Timer(const Duration(milliseconds: 400), _proceedToHome);
      } else {
        _controller.forward();
        _navTimer = Timer(const Duration(milliseconds: 1500), _proceedToHome);
      }
    });
  }

  void _proceedToHome() {
    if (mounted) {
      if (GoRouter.maybeOf(context) != null) {
        context.go(SiliphRoutes.home);
      }
    }
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121218) : Colors.white,
      body: Stack(
        children: [
          // Center brand identity
          Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Opacity(
                  opacity: _opacityAnimation.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Glow & Logo stack
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            // Subtle radial violet brand glow
                            Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    SiliphColors.primary.withValues(
                                      alpha: 0.28 * _glowAnimation.value,
                                    ),
                                    SiliphColors.primary.withValues(alpha: 0.0),
                                  ],
                                ),
                              ),
                            ),
                            // Shimmer overlay on logo
                            ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(SiliphRadii.xl),
                              child: Stack(
                                children: [
                                  Image.asset(
                                    'assets/images/siliph_logo.png',
                                    width: 88,
                                    height: 88,
                                    fit: BoxFit.cover,
                                    filterQuality: FilterQuality.high,
                                  ),
                                  // Shimmer sweep
                                  Positioned.fill(
                                    child: Transform.translate(
                                      offset: Offset(
                                        _shimmerAnimation.value * 88,
                                        0,
                                      ),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              Colors.transparent,
                                              Colors.white.withValues(
                                                alpha: isDark ? 0.15 : 0.35,
                                              ),
                                              Colors.transparent,
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: SiliphSpacing.md),
                        Text(
                          'Siliph',
                          style: textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                            color: isDark
                                ? Colors.white
                                : SiliphColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: SiliphSpacing.xxs),
                        Text(
                          'PDF & File Tools',
                          style: textTheme.bodyMediumStyle.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Bottom brand promise
          Positioned(
            bottom: SiliphSpacing.xxl,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _opacityAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _opacityAnimation.value,
                  child: Center(
                    child: Text(
                      'Private. Fast. On your device.',
                      style: textTheme.labelMediumStyle.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
