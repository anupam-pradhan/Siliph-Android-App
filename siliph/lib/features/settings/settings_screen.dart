/// Settings screen (section 83).
///
/// Appearance, Processing, Storage, Privacy, Accessibility, General, About.
/// Controls are wired to [settingsProvider] so every toggle responds; durable
/// persistence arrives with the data phase.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/siliph_spacing.dart';
import '../../../app/theme/siliph_typography.dart';
import 'settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(SiliphSpacing.md),
        children: [
          _SectionHeader('Appearance'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Theme'),
              subtitle: Text(_themeLabel(settings.theme)),
              onTap: () => _showThemePicker(context, settings.theme, notifier.setTheme),
            ),
          ),
          const SizedBox(height: SiliphSpacing.lg),
          _SectionHeader('Processing'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.filter_none_outlined),
                  title: const Text('Keep original files'),
                  subtitle: const Text('Never overwrite your source files'),
                  value: settings.keepOriginal,
                  onChanged: notifier.setKeepOriginal,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.screenshot_monitor_outlined),
                  title: const Text('Keep screen on'),
                  subtitle: const Text('During long processing'),
                  value: settings.keepScreenOn,
                  onChanged: notifier.setKeepScreenOn,
                ),
              ],
            ),
          ),
          const SizedBox(height: SiliphSpacing.lg),
          _SectionHeader('Privacy'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(SiliphSpacing.md),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline, color: Colors.green),
                  const SizedBox(width: SiliphSpacing.md),
                  const Expanded(
                    child: Text(
                      'Your files stay on your device for local processing.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: SiliphSpacing.lg),
          _SectionHeader('Accessibility'),
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.animation_outlined),
              title: const Text('Reduced motion'),
              subtitle: const Text('Minimize animations'),
              value: settings.reducedMotion,
              onChanged: notifier.setReducedMotion,
            ),
          ),
          const SizedBox(height: SiliphSpacing.lg),
          _SectionHeader('General'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.vibration_outlined),
                  title: const Text('Haptics'),
                  value: settings.haptics,
                  onChanged: notifier.setHaptics,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_none_outlined),
                  title: const Text('Notifications'),
                  value: settings.notifications,
                  onChanged: notifier.setNotifications,
                ),
              ],
            ),
          ),
          const SizedBox(height: SiliphSpacing.lg),
          _SectionHeader('About'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(SiliphRadii.sm),
                    child: Image.asset(
                      'assets/images/siliph_logo.png',
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                  title: const Text('Siliph - PDF & File Tools'),
                  subtitle: const Text('Version 1.0.0'),
                ),
              ],
            ),
          ),
          const SizedBox(height: SiliphSpacing.xxxl),
        ],
      ),
    );
  }

  String _themeLabel(ThemeChoice choice) => switch (choice) {
        ThemeChoice.light => 'Light',
        ThemeChoice.dark => 'Dark',
        ThemeChoice.system => 'System',
      };

  void _showThemePicker(
    BuildContext context,
    ThemeChoice current,
    void Function(ThemeChoice) onSelected,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: RadioGroup<ThemeChoice>(
            groupValue: current,
            onChanged: (value) {
              if (value == null) return;
              onSelected(value);
              Navigator.of(sheetContext).pop();
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final choice in ThemeChoice.values)
                  RadioListTile<ThemeChoice>(
                    title: Text(_themeLabel(choice)),
                    value: choice,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SiliphSpacing.xxs,
        0,
        SiliphSpacing.xxs,
        SiliphSpacing.xs,
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMediumStyle.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
