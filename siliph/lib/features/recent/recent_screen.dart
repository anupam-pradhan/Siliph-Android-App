/// Recent screen (section 82).
///
/// Shows recently-used tools and files picked this session. The durable
/// document library lands with the data phase (section 61).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/siliph_spacing.dart';
import '../../../domain/models/file_item.dart';
import '../../../domain/models/tool_definition.dart';
import '../../../domain/providers.dart';
import '../../../widgets/common/empty_state.dart';

class RecentScreen extends ConsumerWidget {
  const RecentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentIds = ref.watch(recentToolsProvider);
    final registry = ref.watch(toolRegistryProvider);

    final recentTools = recentIds
        .map(registry.byId)
        .whereType<ToolDefinition>()
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Recent')),
      body: ListView(
        padding: const EdgeInsets.all(SiliphSpacing.md),
        children: [
          Text('Recent tools', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: SiliphSpacing.sm),
          if (recentTools.isEmpty)
            const EmptyState(
              icon: Icons.history_outlined,
              title: 'No recent tools',
              message: 'Tools you open will appear here for quick access.',
            )
          else
            Card(
              child: Column(
                children: [
                  for (var i = 0; i < recentTools.length; i++) ...[
                    Builder(builder: (context) {
                      final tool = recentTools[i];
                      return ListTile(
                        leading: Icon(tool.icon, color: tool.category.accent),
                        title: Text(tool.title),
                        subtitle: Text(tool.subtitle),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push(tool.route),
                      );
                    }),
                    if (i < recentTools.length - 1)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: SiliphSpacing.md),
                        child: Divider(),
                      ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: SiliphSpacing.xl),
          Text('Recent files', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: SiliphSpacing.sm),
          _RecentFiles(files: ref.watch(importedFilesProvider)),
        ],
      ),
    );
  }
}

/// Session-scoped file list. Files picked through the "+" launcher or a
/// tool workflow appear here; persistence arrives with the data phase.
class _RecentFiles extends ConsumerWidget {
  const _RecentFiles({required this.files});

  final List<FileItem> files;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (files.isEmpty) {
      return const EmptyState(
        icon: Icons.insert_drive_file_outlined,
        title: 'No recent files',
        message: 'Files you pick or create will appear here.',
      );
    }

    return Card(
      child: Column(
        children: [
          for (var i = 0; i < files.length; i++) ...[
            ListTile(
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: Text(files[i].displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(files[i].formattedSize.isEmpty
                  ? 'This session'
                  : '${files[i].formattedSize} · This session'),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Remove from list',
                onPressed: () =>
                    ref.read(importedFilesProvider.notifier).remove(files[i].uri),
              ),
            ),
            if (i < files.length - 1)
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
