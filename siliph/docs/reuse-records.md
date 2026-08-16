# Source Modification Records

Every module reused from external sources is recorded here (master prompt
section 193). Never lose provenance.

## Record 1: PdfMerger (PDF merge engine)

Source: PdfMerger.kt (merge logic only)
Original repository: https://github.com/Karna14314/Pdf_Tools
Original commit/version: bb4125bf89852527af4b74ace91c71fc87b8d7f3 (2026-08-12)
License: Apache-2.0 (repository LICENSE file)
Files copied/adapted:
- app/src/main/java/com/yourname/pdftoolkit/domain/operations/PdfMerger.kt
Changes made:
- Coroutines (`withContext(Dispatchers.IO)`, `ensureActive`) replaced with a
  single-thread executor + AtomicBoolean cancellation flags, because the
  pigeon-generated Kotlin host handlers reply synchronously on the platform
  thread and must never block.
- Progress/completion/errors are emitted through the typed TaskEventsApi
  bridge instead of a Kotlin callback.
- Output is written to a caller-supplied content URI via ContentResolver
  (SAF) instead of an OutputStream parameter.
- Android Log warning for >50MB totals removed; size policy moves to Dart UI.
- Error results mapped to typed codes: cancelled / invalid_input / io_error /
  not_found / invalid_pdf.
Reason: Stable, reusable native PDF logic; Compose UI intentionally NOT reused
(section 192).
Siliph destination: siliph/android/app/src/main/kotlin/com/siliph/siliph/bridge/PdfBridge.kt

## Record 2: MemoryGuard (heap pre-flight check)

Source: MemoryGuard.kt
Original repository: https://github.com/Karna14314/Pdf_Tools
Original commit/version: bb4125bf89852527af4b74ace91c71fc87b8d7f3 (2026-08-12)
License: Apache-2.0
Files copied/adapted:
- app/src/main/java/com/yourname/pdftoolkit/util/MemoryGuard.kt
Changes made:
- Unused IOException import removed; package renamed; provenance header added.
Reason: Simple, correct heap head-room guard used before heavy processing.
Siliph destination: siliph/android/app/src/main/kotlin/com/siliph/siliph/bridge/MemoryGuard.kt

## Record 3: PdfSplitter / PdfOrganizer (page rearrange pattern)

Source: PdfSplitter.kt (`splitAllPages`, `splitByRanges`, `extractPages`) and
PdfOrganizer.kt (reorder logic)
Original repository: https://github.com/Karna14314/Pdf_Tools
Original commit/version: bb4125bf89852527af4b74ace91c71fc87b8d7f3 (2026-08-12)
License: Apache-2.0
Changes made:
- The three reference operations were collapsed into ONE generic primitive
  (`runRearrange`: load source, `importPage` each zero-based index of a
  caller-supplied order into a new PDDocument, save to a content URI).
  Extract / delete / reorder / reverse / split are all expressed as page
  orders planned in Dart, so there is a single native code path.
- Coroutines replaced with the shared executor + AtomicBoolean task runner
  (same reason as Record 1); events flow through TaskEventsApi.
- Source document stays open until after save (importPage shares source
  resources); MemoryUsageSetting.setupTempFileOnly() applied.
- Progress emitted per page; typed error codes mapped as in Record 1.
Siliph destination: siliph/android/app/src/main/kotlin/com/siliph/siliph/bridge/PdfBridge.kt (runRearrange)

## Record 4: PdfRotator (page rotation loop)

Source: PdfRotator.kt (`rotateAllPages`)
Original repository: https://github.com/Karna14314/Pdf_Tools
Original commit/version: bb4125bf89852527af4b74ace91c71fc87b8d7f3 (2026-08-12)
License: Apache-2.0
Changes made:
- Rotation loop `(currentRotation + delta) % 360` kept, with extra `+360`
  normalization so negative deltas stay valid, and extended from all pages
  to an inclusive one-based page range.
- RotationAngle enum dropped; the angle is a plain int over the bridge.
- Same executor/task-runner, TaskEventsApi, temp-file-only loading and
  typed error mapping as Records 1 and 3.
Siliph destination: siliph/android/app/src/main/kotlin/com/siliph/siliph/bridge/PdfBridge.kt (runRotate)

## Record 5: File utilities (delete / copy / move / share / folder pick)

Source: None — standard Android platform APIs only.
Original repository: n/a
Original commit/version: n/a
License: Apache-2.0 (Android Open Project platform APIs; no third-party code)
Changes made:
- `DocumentsContract.deleteDocument`, `copyDocument`, `moveDocument` used
  directly from `FileAccessBridge`; results that come back null surface as
  typed `not_supported` errors with honest guidance instead of pretending
  success.
- `moveDocument` requires the source parent URI; it is resolved with
  `DocumentsContract.findDocumentPath` (API 26+, matching minSdk) and the
  parent document URI is rebuilt from the provider authority. When a
  provider cannot describe the path the move refuses early and suggests
  copy-then-delete — no silent fallback.
- Folder destinations come from `ACTION_OPEN_DOCUMENT_TREE` with
  read + write + persistable grants, persisted on result (same pattern as
  the document picker).
- Share is `ACTION_SEND` + `EXTRA_STREAM` behind `Intent.createChooser`,
  with `FLAG_GRANT_READ_URI_PERMISSION` so the receiving app can read the
  content URI without broad storage permissions (section 60).
- `metaFor` extended to read `DocumentsContract.Document.COLUMN_LAST_MODIFIED`
  for the File Information view; unknown timestamps stay 0 and render as
  "Unknown" in the UI.
Siliph destination: siliph/android/app/src/main/kotlin/com/siliph/siliph/bridge/FileAccessBridge.kt

## Record 6: PDF suite ops (compress / watermark / protect / unlock / metadata / images<->pdf)

Source: com.tom-roush:pdfbox-android 2.0.27.0 (Apache-2.0 fork of Apache
PDFBox for Android). Public APIs only; no vendored source.
Original repository: https://github.com/TomRoush/pdfbox-android
Original commit/version: 2.0.27.0
License: Apache-2.0
Changes made:
- Compress is an honest rasterized rebuild (section 10): every page is
  rendered with PDFRenderer at a fixed DPI, JPEG-encoded at a fixed
  quality and re-embedded as one image page. The UI states that text
  becomes non-selectable; levels map to (150dpi/80q), (110dpi/65q),
  (80dpi/45q).
- Watermark appends a PDPageContentStream overlay per page
  (AppendMode.APPEND, transparency on). Positions: diagonal (45-degree
  Matrix rotation, page-centre translate), top and bottom margins.
  PDType1Font.HELVETICA_BOLD base font, no font files bundled.
- Protect uses the port's `StandardProtectionPolicy(owner, user,
  AccessPermission)` + `doc.protect(policy)` — verified with javap on the
  shipped AAR; the base-library `StandardProtectionHandler` name does not
  exist in the port.
- Unlock loads with `PDDocument.load(stream, password,
  MemoryUsageSetting.setupTempFileOnly())` and
  `setAllSecurityToBeRemoved(true)` before saving. Wrong passwords catch
  `InvalidPasswordException` and surface typed `invalid_input`
  ("Wrong password"); the UI never claims to remove passwords without one
  (section 14) and refuses non-encrypted files up front.
- Metadata read/write/strip use PDDocumentInformation; strip writes a copy
  with an empty information dictionary.
- Images -> PDF embeds staged copies with the correct extension
  (`PDImageXObject.createFromFileByExtension(File, PDDocument)` — the
  port's 2-argument overload) so non-JPEG inputs fall back to a
  BitmapFactory decode + PNG re-encode.
- PDF -> images renders with PDFRenderer.renderImageWithDPI(...,
  ImageType.RGB) into DocumentsContract children of the picked tree and
  reports created URIs through the new onFilesResult task event before
  onComplete.
Siliph destination: siliph/android/app/src/main/kotlin/com/siliph/siliph/bridge/PdfBridge.kt

## Record 7: QR encoder (QR Code generator)

Source: Project Nayuki QR-Code-generator — QrCode.java and QrSegment.java
(language port only; algorithm tables and structure adapted).
Original repository: https://github.com/nayuki/QR-Code-generator
Original commit/version: master (java/src/main/java/io/nayuki/qrcodegen/,
v1.8.0-era source, fetched 2026-08-16)
License: MIT
Changes made:
- Ported from Java to Kotlin into a single file QrEncoder.kt; byte-mode
  segments only (text is UTF-8 encoded), versions 1-40, four ECC levels.
- Rendering (QRCanvas Swing drawing, mask enums, demo code) dropped;
  kept the encoder core: Reed-Solomon over GF(2^8/0x11D), automatic mask
  selection with penalty scoring, ECL boosting, function-pattern layout.
- Kotlin idiom replacements: `z ^= ...` becomes `z = z xor (...)` (Kotlin
  has no compound xor assignment); arrays become IntArray/BooleanArray.
- Verified structurally off-device with a JVM reflection harness
  (build/qrcheck/QrCheck.java): version selection, module size 25 for
  version 2, finder/timing/dark-module patterns, capacity limits and
  Unicode byte handling all passed.
Siliph destination: siliph/android/app/src/main/kotlin/com/siliph/siliph/bridge/QrEncoder.kt
