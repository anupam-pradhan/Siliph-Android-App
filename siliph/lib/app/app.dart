/// Application root (section 5).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/file_item.dart';
import '../domain/providers.dart';
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Check cold-start launch file (VIEW / SEND intent, section 45)
      try {
        final fileGateway = ref.read(fileGatewayProvider);
        final launchFile = await fileGateway.getLaunchFile();
        if (launchFile != null && mounted) {
          ref.read(importedFilesProvider.notifier).addAll([launchFile]);
        }
      } catch (_) {}

      // Listen for warm incoming files on running instance
      try {
        final bridgeRouter = ref.read(bridgeEventRouterProvider);
        bridgeRouter.incomingFiles.listen((file) {
          if (mounted) {
            ref
                .read(importedFilesProvider.notifier)
                .addAll([FileItem.fromMeta(file)]);
          }
        });
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    return MaterialApp.router(
      title: 'Siliph - PDF & File Tools',
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
