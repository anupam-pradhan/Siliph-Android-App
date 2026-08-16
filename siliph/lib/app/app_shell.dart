/// App shell with adaptive navigation (sections 49, 69, 103, 113).
///
/// Phone: bottom navigation with a center "+" launcher.
/// Tablet / wide: navigation rail on the leading edge.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/models/file_item.dart';
import '../domain/providers.dart';
import 'theme/siliph_colors.dart';
import 'theme/siliph_spacing.dart';
import 'router.dart';

/// Width at which the shell switches from bottom bar to navigation rail.
const double _kRailBreakpoint = 720;

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= _kRailBreakpoint;
        return Scaffold(
          body: Row(
            children: [
              if (useRail) _SiliphRail(currentIndex: navigationShell.currentIndex, onTap: _goBranch, onCenterTap: () => _showCreateSheet(context)),
              Expanded(child: navigationShell),
            ],
          ),
          floatingActionButton: useRail
              ? FloatingActionButton(
                  onPressed: () => _showCreateSheet(context),
                  backgroundColor: SiliphColors.primary,
                  foregroundColor: SiliphColors.onPrimary,
                  child: const Icon(Icons.add),
                )
              : null,
          bottomNavigationBar: useRail
              ? null
              : _SiliphBottomBar(
                  currentIndex: navigationShell.currentIndex,
                  onTap: _goBranch,
                  onCenterTap: () => _showCreateSheet(context),
                ),
        );
      },
    );
  }

  void _showCreateSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => _CreateSheet(onNavigate: (route) {
        Navigator.of(sheetContext).pop();
        context.go(route);
      }),
    );
  }
}

/// Center "+" sheet: Scan / Pick PDF / Pick Images / Pick Files (section 49).
///
/// File picks go through the SAF / Photo Picker bridge (section 60) and land
/// in the session file list; Scan routes to its tool page until the camera
/// phase wires the scanner engine.
class _CreateSheet extends ConsumerWidget {
  const _CreateSheet({required this.onNavigate});

  final ValueChanged<String> onNavigate;

  Future<void> _pick(
    BuildContext context,
    WidgetRef ref,
    Future<List<FileItem>> Function() pick,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    try {
      final picked = await pick();
      if (picked.isEmpty) return;
      ref.read(importedFilesProvider.notifier).addAll(picked);
      messenger.showSnackBar(
        SnackBar(
          content: Text(picked.length == 1
              ? 'Added ${picked.first.displayName}'
              : 'Added ${picked.length} files'),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open the picker.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final files = ref.watch(fileGatewayProvider);

    final items = <(IconData, String, VoidCallback)>[
      (
        Icons.document_scanner_outlined,
        'Scan',
        () {
          Navigator.of(context).pop();
          onNavigate(SiliphRoutes.tool('scan-document'));
        }
      ),
      (
        Icons.picture_as_pdf_outlined,
        'Choose PDF',
        () => _pick(context, ref, () => files.openDocuments(['application/pdf'])),
      ),
      (
        Icons.image_outlined,
        'Choose Images',
        () => _pick(context, ref, () => files.pickImages()),
      ),
      (
        Icons.folder_outlined,
        'Choose Files',
        () => _pick(context, ref, () => files.openDocuments(['*/*'])),
      ),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          SiliphSpacing.md,
          0,
          SiliphSpacing.md,
          SiliphSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Start with a file', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: SiliphSpacing.sm),
            for (final (icon, label, onTap) in items)
              ListTile(
                leading: Icon(icon, color: SiliphColors.primary),
                title: Text(label),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(SiliphRadii.md),
                ),
                onTap: onTap,
              ),
          ],
        ),
      ),
    );
  }
}

/// Bottom navigation for phone widths.
class _SiliphBottomBar extends StatelessWidget {
  const _SiliphBottomBar({
    required this.currentIndex,
    required this.onTap,
    required this.onCenterTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onCenterTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          border: const Border(top: BorderSide(color: SiliphColors.divider)),
        ),
        child: Row(
          children: [
            _NavItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home,
              label: 'Home',
              selected: currentIndex == 0,
              onTap: () => onTap(0),
            ),
            _NavItem(
              icon: Icons.grid_view_outlined,
              activeIcon: Icons.grid_view,
              label: 'Tools',
              selected: currentIndex == 1,
              onTap: () => onTap(1),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: SiliphSpacing.xs),
              child: _CenterButton(onTap: onCenterTap),
            ),
            _NavItem(
              icon: Icons.history_outlined,
              activeIcon: Icons.history,
              label: 'Recent',
              selected: currentIndex == 2,
              onTap: () => onTap(2),
            ),
            _NavItem(
              icon: Icons.settings_outlined,
              activeIcon: Icons.settings,
              label: 'Settings',
              selected: currentIndex == 3,
              onTap: () => onTap(3),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(SiliphRadii.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: SiliphSpacing.xs),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(selected ? activeIcon : icon, color: color, size: 24),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall!.copyWith(color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CenterButton extends StatelessWidget {
  const _CenterButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Create',
      child: Material(
        color: SiliphColors.primary,
        elevation: 2,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsets.all(SiliphSpacing.sm),
            child: Icon(Icons.add, color: SiliphColors.onPrimary, size: 28),
          ),
        ),
      ),
    );
  }
}

/// Navigation rail for tablet / wide layouts.
class _SiliphRail extends StatelessWidget {
  const _SiliphRail({required this.currentIndex, required this.onTap, required this.onCenterTap});

  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onCenterTap;

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      selectedIndex: currentIndex,
      onDestinationSelected: onTap,
      labelType: NavigationRailLabelType.all,
      leading: Padding(
        padding: const EdgeInsets.only(bottom: SiliphSpacing.md),
        child: FloatingActionButton(
          onPressed: onCenterTap,
          backgroundColor: SiliphColors.primary,
          foregroundColor: SiliphColors.onPrimary,
          child: const Icon(Icons.add),
        ),
      ),
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: Text('Home'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.grid_view_outlined),
          selectedIcon: Icon(Icons.grid_view),
          label: Text('Tools'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.history_outlined),
          selectedIcon: Icon(Icons.history),
          label: Text('Recent'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: Text('Settings'),
        ),
      ],
    );
  }
}
