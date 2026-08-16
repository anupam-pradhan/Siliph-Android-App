/// Tool category taxonomy (sections 6, 48, 103, 115).
library;

import 'package:flutter/material.dart';

import '../../app/theme/siliph_colors.dart';

/// High-level tool categories used across Home, Tools, and search.
enum ToolCategory {
  pdf('PDF', Icons.picture_as_pdf_outlined, SiliphColors.categoryPdf),
  images('Images', Icons.image_outlined, SiliphColors.categoryImage),
  scanner('Scanner', Icons.document_scanner_outlined, SiliphColors.categoryScanner),
  ocr('OCR', Icons.text_snippet_outlined, SiliphColors.categoryOcr),
  files('Files', Icons.folder_outlined, SiliphColors.categoryFiles),
  security('Security', Icons.lock_outline, SiliphColors.categorySecurity),
  utilities('Utilities', Icons.build_outlined, SiliphColors.categoryUtilities),
  ai('AI', Icons.auto_awesome_outlined, SiliphColors.categoryAi);

  const ToolCategory(this.label, this.icon, this.accent);

  /// Human-readable category label.
  final String label;

  /// Category icon used for category cards/chips.
  final IconData icon;

  /// Accent color used for category-tinted icon backgrounds.
  final Color accent;
}
