/// PDF Editor tool definitions (section 33).
///
/// Extends the central [ToolRegistry] with the complete PDF Editor feature set.
library;

import 'package:flutter/material.dart';

import '../../domain/models/tool_category.dart';
import '../../domain/models/tool_definition.dart';

/// Unique IDs for each PDF Editor tool.
enum PdfEditorToolId {
  edit,
  text,
  image,
  highlight,
  underline,
  strikethrough,
  draw,
  shape,
  signature,
  link,
  whiteout,
  forms,
  comment,
  search,
  findReplace,
  pages,
  more,
}

/// PDF Editor tool definitions - registered in the [ToolRegistry].
///
/// Availability is [ToolAvailability.ready] since the core editing engines
/// are wired through the native PDF bridge (sections 5-15).
final List<ToolDefinition> pdfEditorTools = const [
  ToolDefinition(
    id: 'pdf_editor-edit',
    title: 'Edit',
    subtitle: 'Modify and format PDF content',
    category: ToolCategory.pdf,
    icon: Icons.edit_outlined,
    keywords: {'edit', 'modify', 'change'},
    availability: ToolAvailability.ready,
    sortPriority: 100,
  ),
  ToolDefinition(
    id: 'pdf_editor-text',
    title: 'Text',
    subtitle: 'Add or edit text on the PDF',
    category: ToolCategory.pdf,
    icon: Icons.text_fields_outlined,
    keywords: {'text', 'edit text', 'font'},
    availability: ToolAvailability.ready,
    sortPriority: 95,
  ),
  ToolDefinition(
    id: 'pdf_editor-image',
    title: 'Image',
    subtitle: 'Add or edit images',
    category: ToolCategory.pdf,
    icon: Icons.image_outlined,
    keywords: {'image', 'photo', 'picture'},
    availability: ToolAvailability.ready,
    sortPriority: 90,
  ),
  ToolDefinition(
    id: 'pdf_editor-highlight',
    title: 'Highlight',
    subtitle: 'Highlight text in the PDF',
    category: ToolCategory.pdf,
    icon: Icons.highlight_outlined,
    keywords: {'highlight', 'mark'},
    availability: ToolAvailability.ready,
    sortPriority: 85,
  ),
  ToolDefinition(
    id: 'pdf_editor-underline',
    title: 'Underline',
    subtitle: 'Underline text in the PDF',
    category: ToolCategory.pdf,
    icon: Icons.format_underlined_outlined,
    keywords: {'underline', 'mark'},
    availability: ToolAvailability.ready,
    sortPriority: 82,
  ),
  ToolDefinition(
    id: 'pdf_editor-strikethrough',
    title: 'Strikethrough',
    subtitle: 'Strikethrough text in the PDF',
    category: ToolCategory.pdf,
    icon: Icons.format_strikethrough_outlined,
    keywords: {'strikethrough', 'mark'},
    availability: ToolAvailability.ready,
    sortPriority: 80,
  ),
  ToolDefinition(
    id: 'pdf_editor-draw',
    title: 'Draw',
    subtitle: 'Draw with pen, pencil or highlighter',
    category: ToolCategory.pdf,
    icon: Icons.brush_outlined,
    keywords: {'pen', 'pencil', 'draw', 'freehand'},
    availability: ToolAvailability.ready,
    sortPriority: 75,
  ),
  ToolDefinition(
    id: 'pdf_editor-shape',
    title: 'Shape',
    subtitle: 'Add rectangles, circles, lines and arrows',
    category: ToolCategory.pdf,
    icon: Icons.square_outlined,
    keywords: {'shape', 'rectangle', 'circle', 'line', 'arrow'},
    availability: ToolAvailability.ready,
    sortPriority: 70,
  ),
  ToolDefinition(
    id: 'pdf_editor-signature',
    title: 'Signature',
    subtitle: 'Add a signature to the PDF',
    category: ToolCategory.pdf,
    icon: Icons.draw_outlined,
    keywords: {'signature', 'sign', 'esign'},
    availability: ToolAvailability.ready,
    sortPriority: 65,
  ),
  ToolDefinition(
    id: 'pdf_editor-link',
    title: 'Link',
    subtitle: 'Add or edit links',
    category: ToolCategory.pdf,
    icon: Icons.link_outlined,
    keywords: {'link', 'url', 'website', 'email', 'page'},
    availability: ToolAvailability.ready,
    sortPriority: 60,
  ),
  ToolDefinition(
    id: 'pdf_editor-whiteout',
    title: 'Whiteout',
    subtitle: 'Cover or redact content',
    category: ToolCategory.pdf,
    icon: Icons.remove_circle_outlined,
    keywords: {'whiteout', 'redact', 'cover'},
    availability: ToolAvailability.ready,
    sortPriority: 55,
  ),
  ToolDefinition(
    id: 'pdf_editor-forms',
    title: 'Forms',
    subtitle: 'Add and fill form fields',
    category: ToolCategory.pdf,
    icon: Icons.format_list_numbered_outlined,
    keywords: {'form', 'field', 'checkbox', 'dropdown', 'fill'},
    availability: ToolAvailability.ready,
    sortPriority: 50,
  ),
  ToolDefinition(
    id: 'pdf_editor-comment',
    title: 'Comment',
    subtitle: 'Add comments and notes',
    category: ToolCategory.pdf,
    icon: Icons.comment_outlined,
    keywords: {'comment', 'note', 'annotation'},
    availability: ToolAvailability.ready,
    sortPriority: 45,
  ),
  ToolDefinition(
    id: 'pdf_editor-search',
    title: 'Search',
    subtitle: 'Search within the PDF',
    category: ToolCategory.pdf,
    icon: Icons.manage_search_outlined,
    keywords: {'search', 'find', 'magnifier'},
    availability: ToolAvailability.ready,
    sortPriority: 40,
  ),
  ToolDefinition(
    id: 'pdf_editor-findReplace',
    title: 'Find & Replace',
    subtitle: 'Search and replace text',
    category: ToolCategory.pdf,
    icon: Icons.find_outlined,
    keywords: {'find', 'replace', 'search', 'text'},
    availability: ToolAvailability.ready,
    sortPriority: 35,
  ),
  ToolDefinition(
    id: 'pdf_editor-pages',
    title: 'Pages',
    subtitle: 'Organize PDF pages',
    category: ToolCategory.pdf,
    icon: Icons.pages_outlined,
    keywords: {'page', 'organize', 'rearrange', 'delete', 'rotate'},
    availability: ToolAvailability.ready,
    sortPriority: 30,
  ),
  ToolDefinition(
    id: 'pdf_editor-more',
    title: 'More',
    subtitle: 'Additional tools and settings',
    category: ToolCategory.pdf,
    icon: Icons.more_outlined,
    keywords: {'settings', 'preferences', 'additional'},
    availability: ToolAvailability.ready,
    sortPriority: 20,
  ),
];

/// Registers all PDF Editor tools into the [ToolRegistry].
///
/// Call this once during app initialization (e.g. in [main.dart] or the
/// router setup) to make the tools available across the app:
/// ```dart
/// toolRegistryProvider.value = toolRegistryProvider.value..addAll(pdfEditorTools);
/// ```
extension PdfEditorToolRegistry on ToolRegistry {
  ToolDefinition? getTool(String id) => _catalog.byId(id);
  Set<ToolDefinition> get pdfEditor => _catalog.where((t) => t.category == ToolCategory.pdf && t.id.startsWith('pdf_editor')).toSet();
  List<ToolDefinition> get pdfEditorReady =>
      _catalog.where((t) => t.category == ToolCategory.pdf && t.availability == ToolAvailability.ready).toList();
}