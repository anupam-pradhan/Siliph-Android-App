/// Settings preferences state (section 83).
///
/// In-memory for build phase 2; durable persistence via DataStore lands in a
/// later phase. Controls respond immediately so nothing is dead.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Theme choice exposed in Settings > Appearance.
enum ThemeChoice { light, dark, system }

/// User preferences surfaced in Settings.
class SettingsState {
  const SettingsState({
    this.theme = ThemeChoice.light,
    this.keepOriginal = true,
    this.keepScreenOn = false,
    this.haptics = true,
    this.notifications = true,
    this.reducedMotion = false,
  });

  final ThemeChoice theme;
  final bool keepOriginal;
  final bool keepScreenOn;
  final bool haptics;
  final bool notifications;
  final bool reducedMotion;

  SettingsState copyWith({
    ThemeChoice? theme,
    bool? keepOriginal,
    bool? keepScreenOn,
    bool? haptics,
    bool? notifications,
    bool? reducedMotion,
  }) {
    return SettingsState(
      theme: theme ?? this.theme,
      keepOriginal: keepOriginal ?? this.keepOriginal,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      haptics: haptics ?? this.haptics,
      notifications: notifications ?? this.notifications,
      reducedMotion: reducedMotion ?? this.reducedMotion,
    );
  }
}

class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() => const SettingsState();

  void setTheme(ThemeChoice choice) => state = state.copyWith(theme: choice);
  void setKeepOriginal(bool value) => state = state.copyWith(keepOriginal: value);
  void setKeepScreenOn(bool value) => state = state.copyWith(keepScreenOn: value);
  void setHaptics(bool value) => state = state.copyWith(haptics: value);
  void setNotifications(bool value) => state = state.copyWith(notifications: value);
  void setReducedMotion(bool value) => state = state.copyWith(reducedMotion: value);
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);
