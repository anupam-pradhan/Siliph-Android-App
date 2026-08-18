/// Scanner mode flavors (document, receipt, ID card, book).
///
/// Each mode configures the detection parameters, UI copy, and output
/// naming. The same camera pipeline handles all modes.
library;

import 'package:flutter/material.dart';

enum ScanMode {
  document(
    title: 'Document Scanner',
    action: 'Scan page',
    hint: 'Point your camera at a document. The scanner will detect edges automatically.',
    outputBase: 'scanned-document',
    icon: Icons.document_scanner_outlined,
    suggestedAspectRatio: 1.414, // A4 ratio
  ),
  receipt(
    title: 'Receipt Scanner',
    action: 'Scan receipt',
    hint: 'Point your camera at a receipt. Hold steady for best results.',
    outputBase: 'scanned-receipt',
    icon: Icons.receipt_long_outlined,
    suggestedAspectRatio: 2.5, // Tall narrow receipt
  ),
  idCard(
    title: 'ID Scanner',
    action: 'Scan card',
    hint: 'Scan the front of your ID card first, then the back.',
    outputBase: 'scanned-id',
    icon: Icons.badge_outlined,
    suggestedAspectRatio: 1.586, // CR80 ID card ratio
  ),
  book(
    title: 'Book Scanner',
    action: 'Scan page',
    hint: 'Point your camera at a book page. Keep it flat for the sharpest result.',
    outputBase: 'scanned-book',
    icon: Icons.auto_stories_outlined,
    suggestedAspectRatio: 0.707, // Portrait book page
  );

  const ScanMode({
    required this.title,
    required this.action,
    required this.hint,
    required this.outputBase,
    required this.icon,
    required this.suggestedAspectRatio,
  });

  final String title;
  final String action;
  final String hint;
  final String outputBase;
  final IconData icon;

  /// Target aspect ratio for document detection (width / height).
  final double suggestedAspectRatio;

  bool get isIdCard => this == ScanMode.idCard;
}
