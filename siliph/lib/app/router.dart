/// Declarative routing (sections 112, 226).
///
/// Routes:
///   /home /tools /recent /settings  -> shell branches
///   /tools/:toolId                  -> tool detail
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/app_shell.dart';
import '../features/annotate/annotate_pdf_screen.dart';
import '../features/archive/zip_create_screen.dart';
import '../features/archive/zip_extract_screen.dart';
import '../features/compress/compress_pdf_screen.dart';
import '../features/convert/images_to_pdf_screen.dart';
import '../features/convert/pdf_to_images_screen.dart';
import '../features/files/copy_move_screen.dart';
import '../features/files/delete_file_screen.dart';
import '../features/files/duplicate_finder_screen.dart';
import '../features/files/file_info_screen.dart';
import '../features/files/rename_file_screen.dart';
import '../features/files/share_file_screen.dart';
import '../features/files/storage_analyzer_screen.dart';
import '../features/metadata/pdf_metadata_screen.dart';
import '../features/ocr/ocr_image_screen.dart';
import '../features/ocr/ocr_pdf_screen.dart';
import '../features/ocr/searchable_pdf_screen.dart';
import '../features/qr/qr_generate_screen.dart';
import '../features/qr/qr_scan_screen.dart';
import '../features/reader/pdf_reader_screen.dart';
import '../features/scan/scan_capture_screen.dart';
import '../features/security/password_security_screen.dart';
import '../features/security/redact_pdf_screen.dart';
import '../features/watermark/watermark_pdf_screen.dart';
import '../features/home/home_screen.dart';
import '../features/images/compress_image_screen.dart';
import '../features/images/convert_image_screen.dart';
import '../features/images/crop_image_screen.dart';
import '../features/images/exact_kb_screen.dart';
import '../features/images/remove_exif_screen.dart';
import '../features/images/resize_image_screen.dart';
import '../features/merge/merge_pdf_screen.dart';
import '../features/pages/page_composer_screen.dart';
import '../features/pages/rotate_pdf_screen.dart';
import '../features/passport/passport_photo_screen.dart';
import '../features/recent/recent_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/signature/sign_pdf_screen.dart';
import '../features/signature/signature_maker_screen.dart';
import '../features/split/split_pdf_screen.dart';
import '../features/tools/tool_detail_screen.dart';
import '../features/tools/tools_screen.dart';

/// Route path constants.
abstract final class SiliphRoutes {
  static const String home = '/home';
  static const String tools = '/tools';
  static const String recent = '/recent';
  static const String settings = '/settings';
  static const String toolDetail = '/tools/:toolId';
  static const String mergePdfWorkflow = '/workflows/pdf-merge';
  static const String splitPdfWorkflow = '/workflows/pdf-split';
  static const String rotatePagesWorkflow = '/workflows/pdf-rotate';
  static const String extractPagesWorkflow = '/workflows/pdf-extract';
  static const String deletePagesWorkflow = '/workflows/pdf-delete';
  static const String reorderPagesWorkflow = '/workflows/pdf-reorder';
  static const String renameFileWorkflow = '/workflows/file-rename';
  static const String fileInfoWorkflow = '/workflows/file-info';
  static const String deleteFileWorkflow = '/workflows/file-delete';
  static const String copyFileWorkflow = '/workflows/file-copy';
  static const String moveFileWorkflow = '/workflows/file-move';
  static const String shareFileWorkflow = '/workflows/file-share';
  static const String compressPdfWorkflow = '/workflows/pdf-compress';
  static const String watermarkPdfWorkflow = '/workflows/pdf-watermark';
  static const String protectPdfWorkflow = '/workflows/pdf-protect';
  static const String unlockPdfWorkflow = '/workflows/pdf-unlock';
  static const String pdfMetadataWorkflow = '/workflows/pdf-metadata';
  static const String imagesToPdfWorkflow = '/workflows/images-to-pdf';
  static const String imageToPdfWorkflow = '/workflows/image-to-pdf';
  static const String pdfToImagesWorkflow = '/workflows/pdf-to-images';
  static const String zipCreateWorkflow = '/workflows/zip-create';
  static const String zipExtractWorkflow = '/workflows/zip-extract';
  static const String duplicateFinderWorkflow = '/workflows/duplicate-finder';
  static const String storageAnalyzerWorkflow = '/workflows/storage-analyzer';
  static const String qrGenerateWorkflow = '/workflows/qr-generate';
  static const String compressImageWorkflow = '/workflows/compress-image';
  static const String exactKbWorkflow = '/workflows/exact-kb';
  static const String resizeImageWorkflow = '/workflows/resize-image';
  static const String cropImageWorkflow = '/workflows/crop-image';
  static const String convertImageWorkflow = '/workflows/convert-image';
  static const String removeExifWorkflow = '/workflows/remove-exif';
  static const String signatureMakerWorkflow = '/workflows/signature-maker';
  static const String passportPhotoWorkflow = '/workflows/passport-photo';
  static const String pdfReaderWorkflow = '/workflows/pdf-reader';
  static const String scanDocumentWorkflow = '/workflows/scan-document';
  static const String scanReceiptWorkflow = '/workflows/scan-receipt';
  static const String scanIdWorkflow = '/workflows/scan-id';
  static const String scanBookWorkflow = '/workflows/scan-book';
  static const String qrScanWorkflow = '/workflows/qr-scan';
  static const String ocrImageWorkflow = '/workflows/ocr-image';
  static const String ocrPdfWorkflow = '/workflows/ocr-pdf';
  static const String searchablePdfWorkflow = '/workflows/searchable-pdf';
  static const String signPdfWorkflow = '/workflows/sign-pdf';
  static const String annotatePdfWorkflow = '/workflows/annotate-pdf';
  static const String redactPdfWorkflow = '/workflows/redact-pdf';

  static String tool(String toolId) => '/tools/$toolId';

  /// Full-screen workflow route for a ready tool, or null when the tool has
  /// no wired workflow yet (section 99: never navigate to a dead screen).
  static String? workflowFor(String toolId) => switch (toolId) {
        'merge-pdf' => mergePdfWorkflow,
        'split-pdf' => splitPdfWorkflow,
        'rotate-pages' => rotatePagesWorkflow,
        'extract-pages' => extractPagesWorkflow,
        'delete-pages' => deletePagesWorkflow,
        'reorder-pages' => reorderPagesWorkflow,
        'rename-file' => renameFileWorkflow,
        'file-info' => fileInfoWorkflow,
        'delete-file' => deleteFileWorkflow,
        'copy-file' => copyFileWorkflow,
        'move-file' => moveFileWorkflow,
        'share-file' => shareFileWorkflow,
        'compress-pdf' => compressPdfWorkflow,
        'watermark-pdf' => watermarkPdfWorkflow,
        'protect-pdf' => protectPdfWorkflow,
        'unlock-pdf' => unlockPdfWorkflow,
        'pdf-metadata' => pdfMetadataWorkflow,
        'images-to-pdf' => imagesToPdfWorkflow,
        'image-to-pdf' => imageToPdfWorkflow,
        'pdf-to-images' => pdfToImagesWorkflow,
        'zip-create' => zipCreateWorkflow,
        'zip-extract' => zipExtractWorkflow,
        'duplicate-finder' => duplicateFinderWorkflow,
        'storage-analyzer' => storageAnalyzerWorkflow,
        'qr-generate' => qrGenerateWorkflow,
        'compress-image' => compressImageWorkflow,
        'exact-kb' => exactKbWorkflow,
        'resize-image' => resizeImageWorkflow,
        'crop-image' => cropImageWorkflow,
        'convert-image' => convertImageWorkflow,
        'remove-exif' => removeExifWorkflow,
        'signature-maker' => signatureMakerWorkflow,
        'passport-photo' => passportPhotoWorkflow,
        'pdf-reader' => pdfReaderWorkflow,
        'scan-document' => scanDocumentWorkflow,
        'scan-receipt' => scanReceiptWorkflow,
        'scan-id' => scanIdWorkflow,
        'scan-book' => scanBookWorkflow,
        'qr-scan' => qrScanWorkflow,
        'ocr-image' => ocrImageWorkflow,
        'ocr-pdf' => ocrPdfWorkflow,
        'searchable-pdf' => searchablePdfWorkflow,
        'sign-pdf' => signPdfWorkflow,
        'annotate-pdf' => annotatePdfWorkflow,
        'redact-pdf' => redactPdfWorkflow,
        _ => null,
      };
}

/// Builds the app router.
GoRouter buildRouter() {
  return GoRouter(
    initialLocation: SiliphRoutes.home,
    debugLogDiagnostics: false,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: SiliphRoutes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: SiliphRoutes.tools,
                builder: (context, state) => const ToolsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: SiliphRoutes.recent,
                builder: (context, state) => const RecentScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: SiliphRoutes.settings,
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: SiliphRoutes.toolDetail,
        builder: (context, state) {
          final toolId = state.pathParameters['toolId'] ?? '';
          return ToolDetailScreen(toolId: toolId);
        },
      ),
      GoRoute(
        path: SiliphRoutes.mergePdfWorkflow,
        builder: (context, state) => const MergePdfScreen(),
      ),
      GoRoute(
        path: SiliphRoutes.splitPdfWorkflow,
        builder: (context, state) => const SplitPdfScreen(),
      ),
      GoRoute(
        path: SiliphRoutes.rotatePagesWorkflow,
        builder: (context, state) => const RotatePdfScreen(),
      ),
      GoRoute(
        path: SiliphRoutes.extractPagesWorkflow,
        builder: (context, state) =>
            const PageComposerScreen(mode: ComposerMode.extract),
      ),
      GoRoute(
        path: SiliphRoutes.deletePagesWorkflow,
        builder: (context, state) =>
            const PageComposerScreen(mode: ComposerMode.delete),
      ),
      GoRoute(
        path: SiliphRoutes.reorderPagesWorkflow,
        builder: (context, state) =>
            const PageComposerScreen(mode: ComposerMode.reorder),
      ),
      GoRoute(
        path: SiliphRoutes.renameFileWorkflow,
        builder: (context, state) => const RenameFileScreen(),
      ),
      GoRoute(
        path: SiliphRoutes.fileInfoWorkflow,
        builder: (context, state) => const FileInfoScreen(),
      ),
      GoRoute(
        path: SiliphRoutes.deleteFileWorkflow,
        builder: (context, state) => const DeleteFileScreen(),
      ),
      GoRoute(
        path: SiliphRoutes.copyFileWorkflow,
        builder: (context, state) =>
            const CopyMoveScreen(mode: TransferMode.copy),
      ),
      GoRoute(
        path: SiliphRoutes.moveFileWorkflow,
        builder: (context, state) =>
            const CopyMoveScreen(mode: TransferMode.move),
      ),
      GoRoute(
        path: SiliphRoutes.shareFileWorkflow,
        builder: (context, state) => const ShareFileScreen(),
      ),
      GoRoute(
        path: SiliphRoutes.compressPdfWorkflow,
        builder: (context, state) => const CompressPdfScreen(),
      ),
      GoRoute(
        path: SiliphRoutes.watermarkPdfWorkflow,
        builder: (context, state) => const WatermarkPdfScreen(),
      ),
      GoRoute(
        path: SiliphRoutes.protectPdfWorkflow,
        builder: (context, state) =>
            const PasswordSecurityScreen(mode: SecurityMode.protect),
      ),
      GoRoute(
        path: SiliphRoutes.unlockPdfWorkflow,
        builder: (context, state) =>
            const PasswordSecurityScreen(mode: SecurityMode.unlock),
      ),
      GoRoute(
        path: SiliphRoutes.pdfMetadataWorkflow,
        builder: (context, state) => const PdfMetadataScreen(),
      ),
      GoRoute(
        path: SiliphRoutes.imagesToPdfWorkflow,
        builder: (context, state) => const ImagesToPdfScreen(),
      ),
      GoRoute(
        path: SiliphRoutes.imageToPdfWorkflow,
        builder: (context, state) => const ImagesToPdfScreen(single: true),
      ),
      GoRoute(
        path: SiliphRoutes.pdfToImagesWorkflow,
        builder: (context, state) => const PdfToImagesScreen(),
      ),
      GoRoute(
        path: SiliphRoutes.zipCreateWorkflow,
        builder: (context, state) => const ZipCreateScreen(),
      ),
      GoRoute(
        path: SiliphRoutes.zipExtractWorkflow,
        builder: (context, state) => const ZipExtractScreen(),
      ),
      GoRoute(
        path: SiliphRoutes.duplicateFinderWorkflow,
        builder: (context, state) => const DuplicateFinderScreen(),
      ),
      GoRoute(
        path: SiliphRoutes.storageAnalyzerWorkflow,
        builder: (context, state) => const StorageAnalyzerScreen(),
      ),
      GoRoute(
        path: SiliphRoutes.qrGenerateWorkflow,
        builder: (context, state) => const QrGenerateScreen(),
      ),
      GoRoute(
        path: SiliphRoutes.compressImageWorkflow,
        builder: (context, state) => const CompressImageScreen(),
      ),
      GoRoute(
        path: SiliphRoutes.exactKbWorkflow,
        builder: (context, state) => const ExactKbScreen(),
      ),
      GoRoute(
        path: SiliphRoutes.resizeImageWorkflow,
        builder: (context, state) => const ResizeImageScreen(),
      ),
      GoRoute(
        path: SiliphRoutes.cropImageWorkflow,
        builder: (context, state) => const CropImageScreen(),
      ),
      GoRoute(
        path: SiliphRoutes.convertImageWorkflow,
        builder: (context, state) => const ConvertImageScreen(),
      ),
      GoRoute(
        path: SiliphRoutes.removeExifWorkflow,
        builder: (context, state) => const RemoveExifScreen(),
      ),
      GoRoute(
        path: SiliphRoutes.signatureMakerWorkflow,
        builder: (context, state) => const SignatureMakerScreen(),
      ),
      GoRoute(
        path: SiliphRoutes.passportPhotoWorkflow,
        builder: (context, state) => const PassportPhotoScreen(),
      ),
      GoRoute(
        path: SiliphRoutes.pdfReaderWorkflow,
        builder: (context, state) => const PdfReaderScreen(),
      ),
      GoRoute(
        path: SiliphRoutes.scanDocumentWorkflow,
        builder: (context, state) =>
            const ScanCaptureScreen(mode: ScanMode.document),
      ),
      GoRoute(
        path: SiliphRoutes.scanReceiptWorkflow,
        builder: (context, state) =>
            const ScanCaptureScreen(mode: ScanMode.receipt),
      ),
      GoRoute(
        path: SiliphRoutes.scanIdWorkflow,
        builder: (context, state) =>
            const ScanCaptureScreen(mode: ScanMode.idCard),
      ),
      GoRoute(
        path: SiliphRoutes.scanBookWorkflow,
        builder: (context, state) =>
            const ScanCaptureScreen(mode: ScanMode.book),
      ),
      GoRoute(
        path: SiliphRoutes.qrScanWorkflow,
        builder: (context, state) => const QrScanScreen(),
      ),
      GoRoute(
        path: SiliphRoutes.ocrImageWorkflow,
        builder: (context, state) => const OcrImageScreen(),
      ),
      GoRoute(
        path: SiliphRoutes.ocrPdfWorkflow,
        builder: (context, state) => const OcrPdfScreen(),
      ),
      GoRoute(
        path: SiliphRoutes.searchablePdfWorkflow,
        builder: (context, state) => const SearchablePdfScreen(),
      ),
      GoRoute(
        path: SiliphRoutes.signPdfWorkflow,
        builder: (context, state) => const SignPdfScreen(),
      ),
      GoRoute(
        path: SiliphRoutes.annotatePdfWorkflow,
        builder: (context, state) => const AnnotatePdfScreen(),
      ),
      GoRoute(
        path: SiliphRoutes.redactPdfWorkflow,
        builder: (context, state) => const RedactPdfScreen(),
      ),
    ],
    errorBuilder: (context, state) => const _NotFoundScreen(),
  );
}

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Not found')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("That page doesn't exist."),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go(SiliphRoutes.home),
              child: const Text('Go home'),
            ),
          ],
        ),
      ),
    );
  }
}
