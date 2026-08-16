/// Central [ToolDefinition] model (section 6).
///
/// A single source of truth for every tool. Home quick actions, the tool
/// catalog, global search, categories, favorites and recommendations all
/// read from this registry — never duplicated per screen.
library;

import 'package:flutter/material.dart';

import 'tool_category.dart';

/// Availability of a tool in the current build.
enum ToolAvailability {
  /// Fully wired and functional.
  ready,

  /// Registered but its engine is not wired yet. Hidden from launch surfaces
  /// until ready (section 99: no visible placeholders).
  planned,
}

/// Immutable description of a single Siliph tool.
@immutable
class ToolDefinition {
  const ToolDefinition({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.icon,
    required this.keywords,
    this.supportsBatch = false,
    this.requiresCamera = false,
    this.requiresNetwork = false,
    this.availability = ToolAvailability.ready,
    this.sortPriority = 0,
    this.aliases = const {},
  });

  /// Stable unique identifier, used for routing and favorites.
  final String id;

  /// Short display name.
  final String title;

  /// One-line explanation (section 160).
  final String subtitle;

  final ToolCategory category;

  final IconData icon;

  /// Lower-case search keywords (section 6).
  final Set<String> keywords;

  /// Additional natural-language aliases for fuzzy search (section 159).
  final Set<String> aliases;

  final bool supportsBatch;
  final bool requiresCamera;
  final bool requiresNetwork;
  final ToolAvailability availability;

  /// Higher values surface earlier within a category.
  final int sortPriority;

  /// Route location for this tool.
  String get route => '/tools/$id';
}
