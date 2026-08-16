/// Application root (section 5).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/settings_provider.dart';
import 'router.dart';
import 'theme/siliph_theme.dart';

/// The Siliph application widget.
class SiliphApp extends ConsumerStatefulWidget {
  const SiliphApp({super.key});

  @override
  ConsumerState<SiliphApp> createState() => _SiliphAppState();
}

class _SiliphAppState extends ConsumerState<SiliphApp> {
  late final _router = buildRouter();

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    return MaterialApp.router(
      title: 'Siliph',
      debugShowCheckedModeBanner: false,
      theme: SiliphTheme.build(brightness: Brightness.light),
      darkTheme: SiliphTheme.build(brightness: Brightness.dark),
      themeMode: switch (settings.theme) {
        ThemeChoice.light => ThemeMode.light,
        ThemeChoice.dark => ThemeMode.dark,
        ThemeChoice.system => ThemeMode.system,
      },
      routerConfig: _router,
    );
  }
}
