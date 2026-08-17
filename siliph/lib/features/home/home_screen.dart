/// Home screen (sections 47, 114).
///
/// Useful immediately: header, hero, live local search, categories, quick
/// actions and recent files. When there is no history the recent section
/// shows an action-oriented empty state instead of blank space.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/siliph_colors.dart';
import '../../../app/theme/siliph_spacing.dart';
import '../../../app/theme/siliph_typography.dart';
import '../../../domain/models/tool_category.dart';
import '../../../domain/models/tool_definition.dart';
import '../../../domain/providers.dart';
import '../../../widgets/cards/tool_card.dart';
import '../../../widgets/common/empty_state.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openTool(ToolDefinition tool) {
    ref.read(recentToolsProvider.notifier).record(tool.id);
    context.push(tool.route);
  }

  @override
  Widget build(BuildContext context) {
    final registry = ref.watch(toolRegistryProvider);
    final favorites = ref.watch(favoritesProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _HomeHeader()),
            SliverToBoxAdapter(child: _HomeHero()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: SiliphSpacing.md),
                child: _HomeSearchField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
            ),
            if (_query.trim().isNotEmpty)
              _SearchResults(
                query: _query,
                favorites: favorites,
                onOpen: _openTool,
                onToggleFavorite: (id) =>
                    ref.read(favoritesProvider.notifier).toggle(id),
              )
            else ...[
              SliverToBoxAdapter(
                child: _CategoryRow(onCategoryTap: () => context.go(SiliphRoutes.tools)),
              ),
              SliverToBoxAdapter(child: _SectionTitle('Quick actions')),
              _QuickActionsGrid(
                tools: registry.quickActions,
                favorites: favorites,
                onOpen: _openTool,
                onToggleFavorite: (id) =>
                    ref.read(favoritesProvider.notifier).toggle(id),
              ),
              SliverToBoxAdapter(child: _SectionTitle('Recent files')),
              const SliverToBoxAdapter(child: _RecentEmptyState()),
              const SliverPadding(padding: EdgeInsets.only(bottom: SiliphSpacing.xxxl)),
            ],
          ],
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SiliphSpacing.md,
        SiliphSpacing.md,
        SiliphSpacing.md,
        0,
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(SiliphRadii.md),
            child: Image.asset(
              'assets/images/siliph_logo.png',
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
          ),
          const SizedBox(width: SiliphSpacing.sm),
          Text('Siliph', style: Theme.of(context).textTheme.titleLarge),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.go(SiliphRoutes.settings),
          ),
        ],
      ),
    );
  }
}

class _HomeHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SiliphSpacing.md,
        SiliphSpacing.lg,
        SiliphSpacing.md,
        SiliphSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('All-in-one File Tools', style: textTheme.displaySmall),
          const SizedBox(height: SiliphSpacing.xxs),
          Text(
            'Private. Fast. On your device.',
            style: textTheme.bodyMediumStyle.copyWith(color: SiliphColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _HomeSearchField extends StatelessWidget {
  const _HomeSearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: const InputDecoration(
        hintText: 'What do you want to do?',
        prefixIcon: Icon(Icons.search),
      ),
    );
  }
}

class _SearchResults extends ConsumerWidget {
  const _SearchResults({
    required this.query,
    required this.favorites,
    required this.onOpen,
    required this.onToggleFavorite,
  });

  final String query;
  final Set<String> favorites;
  final ValueChanged<ToolDefinition> onOpen;
  final ValueChanged<String> onToggleFavorite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final search = ref.watch(toolSearchProvider);
    final results = search.search(query, favoriteIds: favorites);

    if (results.isEmpty) {
      return SliverToBoxAdapter(
        child: EmptyState(
          icon: Icons.search_off_outlined,
          title: 'No matching tools',
          message: 'Try a different word, like "compress" or "scan".',
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(SiliphSpacing.md),
      sliver: SliverGrid.builder(
        itemCount: results.length,
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          mainAxisSpacing: SiliphSpacing.sm,
          crossAxisSpacing: SiliphSpacing.sm,
          childAspectRatio: 1.25,
        ),
        itemBuilder: (context, index) {
          final tool = results[index];
          return ToolCard(
            tool: tool,
            isFavorite: favorites.contains(tool.id),
            onTap: () => onOpen(tool),
            onToggleFavorite: () => onToggleFavorite(tool.id),
          );
        },
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.onCategoryTap});

  final VoidCallback onCategoryTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SiliphSpacing.md,
        SiliphSpacing.lg,
        SiliphSpacing.md,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle('Categories', padding: EdgeInsets.zero),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: ToolCategory.values.length,
              separatorBuilder: (_, _) => const SizedBox(width: SiliphSpacing.sm),
              itemBuilder: (context, index) {
                final category = ToolCategory.values[index];
                return _CategoryCard(category: category, onTap: onCategoryTap);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category, required this.onTap});

  final ToolCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: category.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SiliphRadii.lg),
        child: Container(
          width: 84,
          padding: const EdgeInsets.symmetric(vertical: SiliphSpacing.sm),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(SiliphRadii.lg),
            border: Border.all(color: SiliphColors.divider),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: category.accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(category.icon, color: category.accent, size: 20),
              ),
              const SizedBox(height: SiliphSpacing.xxs),
              Text(
                category.label,
                style: Theme.of(context).textTheme.labelSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.padding = const EdgeInsets.fromLTRB(16, 20, 16, 8)});

  final String text;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid({
    required this.tools,
    required this.favorites,
    required this.onOpen,
    required this.onToggleFavorite,
  });

  final List<ToolDefinition> tools;
  final Set<String> favorites;
  final ValueChanged<ToolDefinition> onOpen;
  final ValueChanged<String> onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: SiliphSpacing.md),
      sliver: SliverGrid.builder(
        itemCount: tools.length,
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          mainAxisSpacing: SiliphSpacing.sm,
          crossAxisSpacing: SiliphSpacing.sm,
          childAspectRatio: 1.25,
        ),
        itemBuilder: (context, index) {
          final tool = tools[index];
          return ToolCard(
            tool: tool,
            isFavorite: favorites.contains(tool.id),
            onTap: () => onOpen(tool),
            onToggleFavorite: () => onToggleFavorite(tool.id),
          );
        },
      ),
    );
  }
}

class _RecentEmptyState extends ConsumerWidget {
  const _RecentEmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return EmptyState(
      icon: Icons.history_outlined,
      title: 'Start with a file',
      message: 'Scan a document, choose a PDF, or select images. '
          'Your processed files will appear here.',
      actions: [
        EmptyStateAction('Scan', () => context.push(SiliphRoutes.tool('scan-document'))),
        EmptyStateAction('Choose PDF', () => context.go(SiliphRoutes.tools)),
        EmptyStateAction('Choose Images', () => context.go(SiliphRoutes.tools)),
      ],
    );
  }
}
