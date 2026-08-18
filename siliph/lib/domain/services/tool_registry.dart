/// Central tool registry (sections 6, 115).
///
/// Single source of truth for every Siliph tool. Screens, search, favorites
/// and recommendations all read from here.
///
/// Availability note (build phase 2): the processing engines land in master
/// prompt phases 5-15. Tools whose engine is not yet wired are registered as
/// [ToolAvailability.planned] so the UI shows honest info without a fake
/// "process" button (section 99). As each engine is connected, its tools are
/// promoted to [ToolAvailability.ready].
library;

import 'package:flutter/material.dart';

import '../models/tool_category.dart';
import '../models/tool_definition.dart';
import '../../features/pdf_editor/tool_definitions.dart';

/// Immutable registry of all Siliph tools.
class ToolRegistry {
  const ToolRegistry();

  /// All registered tools, in display order.
  List<ToolDefinition> get all => _catalog;

  /// Tools currently wired and runnable.
  List<ToolDefinition> get ready =>
      _catalog.where((t) => t.availability == ToolAvailability.ready).toList();

  /// Tools in a given category.
  List<ToolDefinition> inCategory(ToolCategory category) =>
      _catalog.where((t) => t.category == category).toList();

  /// Lookup a tool by id.
  ToolDefinition? byId(String id) {
    for (final tool in _catalog) {
      if (tool.id == id) return tool;
    }
    return null;
  }

  /// High-priority quick actions surfaced on Home (sections 47, 114).
  List<ToolDefinition> get quickActions => const [
        'compress-pdf',
        'merge-pdf',
        'scan-document',
        'compress-image',
        'images-to-pdf',
        'ocr-image',
      ]
          .map(byId)
          .whereType<ToolDefinition>()
          .toList() +
          pdfEditorTools.where((t) => t.category == ToolCategory.pdf).toList();
}

ToolDefinition _tool({
  required String id,
  required String title,
  required String subtitle,
  required ToolCategory category,
  required IconData icon,
  Set<String> keywords = const {},
  Set<String> aliases = const {},
  bool supportsBatch = false,
  bool requiresCamera = false,
  bool requiresNetwork = false,
  ToolAvailability availability = ToolAvailability.planned,
  int sortPriority = 0,
}) {
  return ToolDefinition(
    id: id,
    title: title,
    subtitle: subtitle,
    category: category,
    icon: icon,
    keywords: keywords,
    aliases: aliases,
    supportsBatch: supportsBatch,
    requiresCamera: requiresCamera,
    requiresNetwork: requiresNetwork,
    availability: availability,
    sortPriority: sortPriority,
  );
}

final List<ToolDefinition> _catalog = [
  // --- PDF ----------------------------------------------------------------
  _tool(
    id: 'pdf-reader',
    title: 'PDF Reader',
    subtitle: 'Open, read and search PDF files.',
    category: ToolCategory.pdf,
    icon: Icons.menu_book_outlined,
    keywords: {'open', 'read', 'view', 'search'},
    aliases: {'open pdf', 'read pdf'},
    sortPriority: 100,
    // Page-by-page native rendering with pinch zoom; search is not
    // implemented yet (honest scope).
    availability: ToolAvailability.ready,
  ),
  _tool(
    id: 'merge-pdf',
    title: 'Merge PDF',
    subtitle: 'Combine multiple PDFs into one.',
    category: ToolCategory.pdf,
    icon: Icons.merge_type_outlined,
    keywords: {'combine', 'join', 'merge'},
    aliases: {'combine pdf', 'join pdf'},
    supportsBatch: true,
    sortPriority: 90,
    // Native pdfbox engine wired through the Pigeon bridge (phase 3).
    availability: ToolAvailability.ready,
  ),
  _tool(
    id: 'split-pdf',
    title: 'Split PDF',
    subtitle: 'Split by range or every N pages.',
    category: ToolCategory.pdf,
    icon: Icons.content_cut_outlined,
    keywords: {'divide', 'separate', 'range'},
    // Native pdfbox engine wired through the Pigeon bridge (phase 6).
    availability: ToolAvailability.ready,
  ),
  _tool(
    id: 'compress-pdf',
    title: 'Compress PDF',
    subtitle: 'Reduce PDF file size.',
    category: ToolCategory.pdf,
    icon: Icons.compress_outlined,
    keywords: {'reduce', 'shrink', 'smaller', 'size'},
    aliases: {'reduce pdf', 'shrink pdf', 'make pdf smaller'},
    sortPriority: 95,
    // Rasterized recompression on the native engine; honesty copy in the UI.
    availability: ToolAvailability.ready,
  ),
  _tool(
    id: 'extract-pages',
    title: 'Extract Pages',
    subtitle: 'Save selected pages as a new PDF.',
    category: ToolCategory.pdf,
    icon: Icons.file_copy_outlined,
    keywords: {'pages', 'save', 'extract'},
    availability: ToolAvailability.ready,
  ),
  _tool(
    id: 'delete-pages',
    title: 'Delete Pages',
    subtitle: 'Remove pages from a PDF.',
    category: ToolCategory.pdf,
    icon: Icons.delete_outline,
    keywords: {'remove', 'pages'},
    availability: ToolAvailability.ready,
  ),
  _tool(
    id: 'reorder-pages',
    title: 'Reorder Pages',
    subtitle: 'Drag pages into a new order.',
    category: ToolCategory.pdf,
    icon: Icons.low_priority_outlined,
    keywords: {'sort', 'arrange', 'order'},
    availability: ToolAvailability.ready,
  ),
  _tool(
    id: 'rotate-pages',
    title: 'Rotate Pages',
    subtitle: 'Rotate PDF pages.',
    category: ToolCategory.pdf,
    icon: Icons.rotate_right_outlined,
    keywords: {'turn', 'orientation'},
    availability: ToolAvailability.ready,
  ),
  _tool(
    id: 'pdf-to-images',
    title: 'PDF to Image',
    subtitle: 'Convert PDF pages to JPG or PNG.',
    category: ToolCategory.pdf,
    icon: Icons.photo_library_outlined,
    keywords: {'convert', 'jpg', 'png', 'image'},
    aliases: {'pdf to jpg', 'pdf to png'},
    // Renders pages to PNG into a picked SAF folder.
    availability: ToolAvailability.ready,
  ),
  _tool(
    id: 'images-to-pdf',
    title: 'Images to PDF',
    subtitle: 'Combine images into a single PDF.',
    category: ToolCategory.pdf,
    icon: Icons.picture_as_pdf_outlined,
    keywords: {'convert', 'images', 'create'},
    aliases: {'jpg to pdf', 'png to pdf', 'convert picture to pdf'},
    supportsBatch: true,
    sortPriority: 85,
    // One page per image on the native engine.
    availability: ToolAvailability.ready,
  ),
  _tool(
    id: 'sign-pdf',
    title: 'Sign PDF',
    subtitle: 'Add an electronic signature.',
    category: ToolCategory.pdf,
    icon: Icons.draw_outlined,
    keywords: {'signature', 'sign', 'esign'},
    // Image stamp placed on one page; visible signature, not cryptographic.
    availability: ToolAvailability.ready,
  ),
  _tool(
    id: 'annotate-pdf',
    title: 'Annotate PDF',
    subtitle: 'Highlight, draw and add notes.',
    category: ToolCategory.pdf,
    icon: Icons.edit_note_outlined,
    keywords: {'highlight', 'draw', 'note', 'markup'},
    // Pen/highlight/box marks baked into the page content stream; text
    // stays selectable.
    availability: ToolAvailability.ready,
  ),
  _tool(
    id: 'watermark-pdf',
    title: 'Watermark PDF',
    subtitle: 'Add a text or image watermark.',
    category: ToolCategory.pdf,
    icon: Icons.branding_watermark_outlined,
    keywords: {'stamp', 'watermark'},
    // Text watermark overlay on every page (image watermark not wired yet).
    availability: ToolAvailability.ready,
  ),
  _tool(
    id: 'protect-pdf',
    title: 'Protect PDF',
    subtitle: 'Add a password to a PDF.',
    category: ToolCategory.security,
    icon: Icons.lock_outline,
    keywords: {'password', 'encrypt', 'secure'},
    // StandardProtectionPolicy encryption of a saved copy.
    availability: ToolAvailability.ready,
  ),
  _tool(
    id: 'unlock-pdf',
    title: 'Unlock PDF',
    subtitle: 'Open a PDF with its password.',
    category: ToolCategory.security,
    icon: Icons.lock_open_outlined,
    keywords: {'password', 'decrypt', 'remove'},
    // Decrypts with the user's password; wrong passwords are reported
    // plainly (section 14 honesty rule).
    availability: ToolAvailability.ready,
  ),
  _tool(
    id: 'redact-pdf',
    title: 'Redact PDF',
    subtitle: 'Permanently remove sensitive content.',
    category: ToolCategory.security,
    icon: Icons.visibility_off_outlined,
    keywords: {'censor', 'hide', 'remove', 'blackout'},
    // True burn-in: marked pages are re-rendered with black boxes and
    // rebuilt, so covered pixels are gone for good.
    availability: ToolAvailability.ready,
  ),
  _tool(
    id: 'pdf-metadata',
    title: 'PDF Metadata',
    subtitle: 'View and edit PDF properties.',
    category: ToolCategory.pdf,
    icon: Icons.info_outline,
    keywords: {'properties', 'info', 'title', 'author'},
    // Read/edit/strip the document-information dictionary on copies.
    availability: ToolAvailability.ready,
  ),
  // PDF Editor tools
  ...pdfEditorTools,
  _tool(
    id: 'pdf-page-numbers',
    title: 'Page Numbers',
    subtitle: 'Add page numbers to PDF.',
    category: ToolCategory.pdf,
    icon: Icons.numbers_outlined,
    keywords: {'number', 'header', 'footer', 'page'},
    availability: ToolAvailability.ready,
  ),
  _tool(
    id: 'pdf-tts',
    title: 'PDF Text-to-Speech',
    subtitle: 'Listen to PDF documents read aloud.',
    category: ToolCategory.pdf,
    icon: Icons.record_voice_over_outlined,
    keywords: {'speech', 'tts', 'listen', 'audio', 'read'},
    availability: ToolAvailability.ready,
  ),

  // --- Images -------------------------------------------------------------
  _tool(
    id: 'compress-image',
    title: 'Compress Image',
    subtitle: 'Reduce image file size.',
    category: ToolCategory.images,
    icon: Icons.compress_outlined,
    keywords: {'reduce', 'shrink', 'smaller', 'photo'},
    aliases: {'reduce photo size', 'make picture smaller'},
    supportsBatch: true,
    sortPriority: 90,
    // BitmapFactory decode + Bitmap.compress re-encode (JPEG/WebP).
    availability: ToolAvailability.ready,
  ),
  _tool(
    id: 'exact-kb',
    title: 'Exact KB',
    subtitle: 'Compress to an exact KB target.',
    category: ToolCategory.images,
    icon: Icons.straighten_outlined,
    keywords: {'target', 'size', 'kb', 'exact'},
    aliases: {'kb photo', 'exact size'},
    // JPEG quality binary search + downscale fallback on the native side.
    availability: ToolAvailability.ready,
  ),
  _tool(
    id: 'resize-image',
    title: 'Resize Image',
    subtitle: 'Change image dimensions.',
    category: ToolCategory.images,
    icon: Icons.aspect_ratio_outlined,
    keywords: {'dimensions', 'scale', 'width', 'height'},
    supportsBatch: true,
    // Bitmap.createScaledBitmap; dimensions inspected before resizing.
    availability: ToolAvailability.ready,
  ),
  _tool(
    id: 'crop-image',
    title: 'Crop Image',
    subtitle: 'Trim an image to a region.',
    category: ToolCategory.images,
    icon: Icons.crop_outlined,
    keywords: {'trim', 'cut'},
    // Centre crop to an aspect ratio; rectangle computed in Dart.
    availability: ToolAvailability.ready,
  ),
  _tool(
    id: 'convert-image',
    title: 'Convert Image',
    subtitle: 'Convert between JPG, PNG and WebP.',
    category: ToolCategory.images,
    icon: Icons.swap_horiz_outlined,
    keywords: {'format', 'jpg', 'png', 'webp', 'heic'},
    supportsBatch: true,
    // Decode any image, re-encode as JPEG/PNG/WebP.
    availability: ToolAvailability.ready,
  ),
  _tool(
    id: 'remove-exif',
    title: 'Remove EXIF',
    subtitle: 'Strip location and device metadata.',
    category: ToolCategory.images,
    icon: Icons.location_off_outlined,
    keywords: {'metadata', 'gps', 'privacy', 'exif'},
    supportsBatch: true,
    // Pixel re-encode drops all EXIF/GPS metadata.
    availability: ToolAvailability.ready,
  ),
  _tool(
    id: 'image-to-pdf',
    title: 'Image to PDF',
    subtitle: 'Turn an image into a PDF page.',
    category: ToolCategory.images,
    icon: Icons.picture_as_pdf_outlined,
    keywords: {'pdf', 'convert'},
    // Single-image variant of the images-to-pdf engine path.
    availability: ToolAvailability.ready,
  ),

  // --- Scanner ------------------------------------------------------------
  _tool(
    id: 'scan-document',
    title: 'Document Scanner',
    subtitle: 'Scan pages with the camera.',
    category: ToolCategory.scanner,
    icon: Icons.document_scanner_outlined,
    keywords: {'scan', 'camera', 'paper', 'document'},
    aliases: {'scan paper', 'document scan', 'camera pdf'},
    requiresCamera: true,
    sortPriority: 95,
    // System camera capture -> one PDF via the images-to-pdf engine.
    availability: ToolAvailability.ready,
  ),
  _tool(
    id: 'scan-receipt',
    title: 'Receipt Scanner',
    subtitle: 'Scan and enhance receipts.',
    category: ToolCategory.scanner,
    icon: Icons.receipt_long_outlined,
    keywords: {'receipt', 'bill', 'scan'},
    requiresCamera: true,
    // Camera capture -> PDF; no contrast enhancement (honest scope).
    availability: ToolAvailability.ready,
  ),
  _tool(
    id: 'scan-id',
    title: 'ID Scanner',
    subtitle: 'Scan ID cards cleanly.',
    category: ToolCategory.scanner,
    icon: Icons.badge_outlined,
    keywords: {'id', 'card', 'scan'},
    requiresCamera: true,
    // Front/back camera capture -> PDF; no auto-crop (honest scope).
    availability: ToolAvailability.ready,
  ),
  _tool(
    id: 'scan-book',
    title: 'Book Scanner',
    subtitle: 'Scan book pages with correction.',
    category: ToolCategory.scanner,
    icon: Icons.auto_stories_outlined,
    keywords: {'book', 'pages', 'scan'},
    requiresCamera: true,
    // Camera capture -> PDF; no curvature correction (honest scope).
    availability: ToolAvailability.ready,
  ),

  // --- OCR ----------------------------------------------------------------
  _tool(
    id: 'ocr-image',
    title: 'OCR',
    subtitle: 'Extract text from images.',
    category: ToolCategory.ocr,
    icon: Icons.text_fields_outlined,
    keywords: {'text', 'extract', 'recognize', 'ocr'},
    aliases: {'extract text', 'read text from image'},
    sortPriority: 90,
    // Bundled on-device ML Kit Latin recognizer.
    availability: ToolAvailability.ready,
  ),
  _tool(
    id: 'ocr-pdf',
    title: 'PDF OCR',
    subtitle: 'Extract text from scanned PDFs.',
    category: ToolCategory.ocr,
    icon: Icons.text_snippet_outlined,
    keywords: {'text', 'pdf', 'extract'},
    // Per-page render + on-device recognition.
    availability: ToolAvailability.ready,
  ),
  _tool(
    id: 'searchable-pdf',
    title: 'Searchable PDF',
    subtitle: 'Add a searchable text layer.',
    category: ToolCategory.ocr,
    icon: Icons.manage_search_outlined,
    keywords: {'text layer', 'search', 'ocr'},
    // Image pages + invisible OCR text layer; selection is approximate.
    availability: ToolAvailability.ready,
  ),

  // --- Files --------------------------------------------------------------
  _tool(
    id: 'rename-file',
    title: 'Rename File',
    subtitle: 'Rename a file where it lives.',
    category: ToolCategory.files,
    icon: Icons.drive_file_rename_outline,
    keywords: {'rename', 'name', 'change name'},
    aliases: {'rename file', 'change file name'},
    sortPriority: 92,
    // SAF DocumentsContract rename wired through the Pigeon bridge.
    availability: ToolAvailability.ready,
  ),
  _tool(
    id: 'file-info',
    title: 'File Information',
    subtitle: 'Inspect name, size and type.',
    category: ToolCategory.files,
    icon: Icons.description_outlined,
    keywords: {'info', 'details', 'size', 'properties'},
    aliases: {'file info', 'file details', 'properties'},
    sortPriority: 91,
    // Read-only metadata view over the SAF bridge.
    availability: ToolAvailability.ready,
  ),
  _tool(
    id: 'delete-file',
    title: 'Delete File',
    subtitle: 'Permanently delete a file.',
    category: ToolCategory.files,
    icon: Icons.delete_outline,
    keywords: {'delete', 'remove', 'erase'},
    aliases: {'delete file', 'remove file'},
    sortPriority: 90,
    // DocumentsContract.deleteDocument behind an explicit confirm dialog.
    availability: ToolAvailability.ready,
  ),
  _tool(
    id: 'copy-file',
    title: 'Copy File',
    subtitle: 'Copy a file into a folder.',
    category: ToolCategory.files,
    icon: Icons.copy_outlined,
    keywords: {'copy', 'duplicate', 'clone'},
    aliases: {'copy file', 'duplicate file'},
    sortPriority: 89,
    // DocumentsContract.copyDocument into a picked destination tree.
    availability: ToolAvailability.ready,
  ),
  _tool(
    id: 'move-file',
    title: 'Move File',
    subtitle: 'Move a file into a folder.',
    category: ToolCategory.files,
    icon: Icons.drive_file_move_outline,
    keywords: {'move', 'relocate', 'transfer'},
    aliases: {'move file', 'cut file'},
    sortPriority: 88,
    // DocumentsContract.moveDocument; parent resolved via findDocumentPath.
    availability: ToolAvailability.ready,
  ),
  _tool(
    id: 'share-file',
    title: 'Share File',
    subtitle: 'Send a file to another app.',
    category: ToolCategory.files,
    icon: Icons.share_outlined,
    keywords: {'share', 'send', 'export'},
    aliases: {'share file', 'send file'},
    sortPriority: 87,
    // ACTION_SEND chooser launched from the bridge.
    availability: ToolAvailability.ready,
  ),
  _tool(
    id: 'zip-create',
    title: 'Create ZIP',
    subtitle: 'Compress files into an archive.',
    category: ToolCategory.files,
    icon: Icons.folder_zip_outlined,
    keywords: {'archive', 'zip', 'compress'},
    supportsBatch: true,
    // ZipOutputStream streams picked files into a SAF document.
    availability: ToolAvailability.ready,
  ),
  _tool(
    id: 'zip-extract',
    title: 'Extract ZIP',
    subtitle: 'Unzip an archive safely.',
    category: ToolCategory.files,
    icon: Icons.unarchive_outlined,
    keywords: {'unzip', 'extract', 'archive'},
    // ZipFile + DocumentsContract.createDocument; zip-slip entries skipped.
    availability: ToolAvailability.ready,
  ),
  _tool(
    id: 'duplicate-finder',
    title: 'Duplicate Finder',
    subtitle: 'Find exact duplicate files.',
    category: ToolCategory.files,
    icon: Icons.copy_all_outlined,
    keywords: {'duplicate', 'same', 'cleanup'},
    // Size pre-grouping + SHA-256 over SAF tree; report-only.
    availability: ToolAvailability.ready,
  ),
  _tool(
    id: 'storage-analyzer',
    title: 'Storage Analyzer',
    subtitle: 'See how storage is used.',
    category: ToolCategory.files,
    icon: Icons.pie_chart_outline,
    keywords: {'storage', 'space', 'usage'},
    // SAF tree walk aggregating top-level children sizes.
    availability: ToolAvailability.ready,
  ),

  // --- Utilities ----------------------------------------------------------
  _tool(
    id: 'qr-scan',
    title: 'QR Scanner',
    subtitle: 'Scan QR codes and barcodes.',
    category: ToolCategory.utilities,
    icon: Icons.qr_code_scanner_outlined,
    keywords: {'qr', 'barcode', 'scan'},
    requiresCamera: true,
    // Photo/gallery image -> bundled ML Kit barcode decoder.
    availability: ToolAvailability.ready,
  ),
  _tool(
    id: 'qr-generate',
    title: 'QR Generator',
    subtitle: 'Create QR codes from text or links.',
    category: ToolCategory.utilities,
    icon: Icons.qr_code_2_outlined,
    keywords: {'qr', 'create', 'generate'},
    // Nayuki QR encoder ported to Kotlin; PNG via SAF save-as.
    availability: ToolAvailability.ready,
  ),
  _tool(
    id: 'signature-maker',
    title: 'Signature Maker',
    subtitle: 'Create and save signatures.',
    category: ToolCategory.utilities,
    icon: Icons.gesture_outlined,
    keywords: {'signature', 'draw', 'sign'},
    // Gesture canvas exported to PNG via the SAF save-as dialog.
    availability: ToolAvailability.ready,
  ),
  _tool(
    id: 'passport-photo',
    title: 'Passport Photo',
    subtitle: 'Size photos for ID documents.',
    category: ToolCategory.utilities,
    icon: Icons.account_box_outlined,
    keywords: {'passport', 'id', 'photo', 'size'},
    // Native 4×6 sheet compositor with 35×45mm slots and cut guides.
    availability: ToolAvailability.ready,
  ),

  // --- AI -----------------------------------------------------------------
  _tool(
    id: 'ai-summarize',
    title: 'Summarize PDF',
    subtitle: 'Get an executive summary & key points on-device.',
    category: ToolCategory.ai,
    icon: Icons.summarize_outlined,
    keywords: {'summary', 'ai', 'tldr', 'key points', 'entities'},
    requiresNetwork: false,
    availability: ToolAvailability.ready,
  ),
  _tool(
    id: 'ai-ask',
    title: 'Ask PDF',
    subtitle: 'Ask questions about a document on-device.',
    category: ToolCategory.ai,
    icon: Icons.question_answer_outlined,
    keywords: {'chat', 'ask', 'ai', 'question', 'citation'},
    requiresNetwork: false,
    availability: ToolAvailability.ready,
  ),
];
