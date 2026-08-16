/// Tool card used in the Tools grid and Home sections (section 48).
///
/// Presentational: the parent wires navigation and favorite toggling so the
/// card stays easy to test.
library;

import 'package:flutter/material.dart';

import '../../app/theme/siliph_spacing.dart';
import '../../domain/models/tool_definition.dart';

class ToolCard extends StatelessWidget {
  const ToolCard({
    super.key,
    required this.tool,
    required this.isFavorite,
    required this.onTap,
    required this.onToggleFavorite,
  });

  final ToolDefinition tool;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final accent = tool.category.accent;

    return Semantics(
      button: true,
      label: tool.title,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(SiliphSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(SiliphRadii.md),
                      ),
                      child: Icon(tool.icon, color: accent, size: 24),
                    ),
                    const Spacer(),
                    IconButton(
                      // Expand hit target to the minimum 48px (section 68).
                      visualDensity: VisualDensity.standard,
                      icon: Icon(
                        isFavorite ? Icons.star : Icons.star_outline,
                        color: isFavorite ? scheme.primary : scheme.onSurfaceVariant,
                      ),
                      tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
                      onPressed: onToggleFavorite,
                    ),
                  ],
                ),
                const SizedBox(height: SiliphSpacing.sm),
                Text(
                  tool.title,
                  style: textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                // Expanded absorbs any residual height so the card never
                // overflows its fixed-aspect grid cell.
                Expanded(
                  child: Text(
                    tool.subtitle,
                    style: textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
