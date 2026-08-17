/// Tools catalog screen (section 48).
///
/// Category chips + instant local search + lazy tool grid.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/siliph_spacing.dart';
import '../../../domain/models/tool_category.dart';
import '../../../domain/models/tool_definition.dart';
import '../../../domain/providers.dart';
import '../../../widgets/cards/tool_card.dart';
import '../../../widgets/common/empty_state.dart';

class ToolsScreen extends ConsumerStatefulWidget {
  const ToolsScreen({super.key});

  @override
  ConsumerState<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends ConsumerState<ToolsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  ToolCategory? _selectedCategory;

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
    final search = ref.watch(toolSearchProvider);

    final searching = _query.trim().isNotEmpty;
    List<ToolDefinition> tools = searching
        ? search.search(_query, favoriteIds: favorites)
        : (_selectedCategory == null
            ? registry.all
            : registry.inCategory(_selectedCategory!));

    return Scaffold(
      appBar: AppBar(title: const Text('Tools')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SiliphSpacing.md,
              0,
              SiliphSpacing.md,
              SiliphSpacing.sm,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Search tools...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
              ),
            ),
          ),
          if (!searching) _CategoryChips(selected: _selectedCategory, onSelected: (c) => setState(() => _selectedCategory = c)),
          Expanded(
            child: tools.isEmpty
                ? EmptyState(
                    icon: Icons.search_off_outlined,
                    title: 'No matching tools',
                    message: 'Try a different word or category.',
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(SiliphSpacing.md),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 220,
                      mainAxisSpacing: SiliphSpacing.sm,
                      crossAxisSpacing: SiliphSpacing.sm,
                      childAspectRatio: 1.25,
                    ),
                    itemCount: tools.length,
                    itemBuilder: (context, index) {
                      final tool = tools[index];
                      return ToolCard(
                        tool: tool,
                        isFavorite: favorites.contains(tool.id),
                        onTap: () => _openTool(tool),
                        onToggleFavorite: () =>
                            ref.read(favoritesProvider.notifier).toggle(tool.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.selected, required this.onSelected});

  final ToolCategory? selected;
  final ValueChanged<ToolCategory?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: SiliphSpacing.md),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: SiliphSpacing.xs),
            child: ChoiceChip(
              label: const Text('All'),
              selected: selected == null,
              onSelected: (_) => onSelected(null),
            ),
          ),
          for (final category in ToolCategory.values)
            Padding(
              padding: const EdgeInsets.only(right: SiliphSpacing.xs),
              child: ChoiceChip(
                avatar: Icon(category.icon, size: 18, color: category.accent),
                label: Text(category.label),
                selected: selected == category,
                onSelected: (isSelected) => onSelected(isSelected ? category : null),
              ),
            ),
        ],
      ),
    );
  }
}
