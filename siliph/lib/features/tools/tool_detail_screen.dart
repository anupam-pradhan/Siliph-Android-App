/// Tool detail screen following the tool-screen standard (section 50).
///
/// Shows real tool metadata and a favorite action. The primary processing CTA
/// is only shown when the tool's engine is wired ([ToolAvailability.ready]),
/// so this build phase ships no dead or placeholder process buttons
/// (section 99).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/siliph_colors.dart';
import '../../../app/theme/siliph_spacing.dart';
import '../../../app/theme/siliph_typography.dart';
import '../../../domain/models/tool_definition.dart';
import '../../../domain/providers.dart';

class ToolDetailScreen extends ConsumerWidget {
  const ToolDetailScreen({super.key, required this.toolId});

  final String toolId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registry = ref.watch(toolRegistryProvider);
    final tool = registry.byId(toolId);

    if (tool == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Tool not found.')),
      );
    }

    final favorites = ref.watch(favoritesProvider);
    final isFavorite = favorites.contains(tool.id);
    final accent = tool.category.accent;

    return Scaffold(
      appBar: AppBar(
        title: Text(tool.title),
        actions: [
          IconButton(
            icon: Icon(
              isFavorite ? Icons.star : Icons.star_outline,
              color: isFavorite ? Theme.of(context).colorScheme.primary : null,
            ),
            tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
            onPressed: () => ref.read(favoritesProvider.notifier).toggle(tool.id),
          ),
          const SizedBox(width: SiliphSpacing.xs),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(SiliphSpacing.md),
        children: [
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(SiliphRadii.xl),
              ),
              child: Icon(tool.icon, color: accent, size: 44),
            ),
          ),
          const SizedBox(height: SiliphSpacing.md),
          Center(
            child: Text(tool.title, style: Theme.of(context).textTheme.headlineSmall),
          ),
          const SizedBox(height: SiliphSpacing.xxs),
          Center(
            child: Text(
              tool.subtitle,
              style: Theme.of(context)
                  .textTheme
                  .bodyMediumStyle
                  .copyWith(color: SiliphColors.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: SiliphSpacing.xl),
          _CapabilityList(tool: tool),
          const SizedBox(height: SiliphSpacing.xl),
          if (tool.availability == ToolAvailability.ready)
            FilledButton.icon(
              onPressed: () {
                final route = SiliphRoutes.workflowFor(tool.id);
                if (route != null) context.push(route);
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start'),
            )
          else
            _AvailabilityNote(category: tool.category.label),
          const SizedBox(height: SiliphSpacing.md),
          const _PrivacyNote(),
        ],
      ),
    );
  }
}

class _CapabilityList extends StatelessWidget {
  const _CapabilityList({required this.tool});

  final ToolDefinition tool;

  @override
  Widget build(BuildContext context) {
    final rows = <(IconData, String, String)>[
      (Icons.category_outlined, 'Category', tool.category.label),
      if (tool.supportsBatch) (Icons.layers_outlined, 'Batch', 'Processes multiple files'),
      if (tool.requiresCamera) (Icons.photo_camera_outlined, 'Camera', 'Uses the device camera'),
      if (tool.requiresNetwork) (Icons.wifi_outlined, 'Internet', 'Requires internet'),
    ];

    return Card(
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            ListTile(
              leading: Icon(rows[i].$1, color: SiliphColors.primary),
              title: Text(rows[i].$2),
              subtitle: Text(rows[i].$3),
            ),
            if (i < rows.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: SiliphSpacing.md),
                child: Divider(),
              ),
          ],
        ],
      ),
    );
  }
}

class _AvailabilityNote extends StatelessWidget {
  const _AvailabilityNote({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(SiliphSpacing.md),
        child: Row(
          children: [
            const Icon(Icons.hourglass_top_outlined, color: SiliphColors.warning),
            const SizedBox(width: SiliphSpacing.sm),
            Expanded(
              child: Text(
                'The $category processing engine is being connected. '
                'This tool will become actionable once its engine is wired.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_outline, size: 14, color: SiliphColors.onSurfaceVariant),
          const SizedBox(width: SiliphSpacing.xxs),
          Text(
            'Processed on your device.',
            style: Theme.of(context)
                .textTheme
                .labelSmallStyle
                .copyWith(color: SiliphColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
