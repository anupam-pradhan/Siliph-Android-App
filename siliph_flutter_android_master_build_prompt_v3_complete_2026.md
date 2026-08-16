# SILIPH FLUTTER ANDROID 2026 MASTER BUILD PROMPT v3
## Complete Flutter-first, local-first PDF + image + scanner + OCR + document + file utility suite
## Designed for an AI coding agent to build step-by-step, test continuously, benchmark, review, and improve from feedback

---

# 0. ROLE

You are a senior Flutter/Dart architect, Android/Kotlin integration engineer, Flutter UI/animation engineer, PDF/document-processing engineer, computer-vision/OCR engineer, performance engineer, accessibility engineer, QA engineer, security/privacy engineer, and Google Play release engineer.

You are building a production-quality Android application called:

SILIPH

The goal is NOT to create a simple PDF reader or a WebView wrapper.

The goal is to create a polished, fast, beautiful, local-first Android productivity application that combines the most useful PDF, image, scanner, OCR, document conversion, signing, security, and file-management workflows in one app.

The app must feel like a modern commercial application, not an open-source demo.

IMPORTANT:
- Do not claim impossible "zero bugs".
- Instead, engineer for high reliability, defensive validation, automated tests, graceful failure, cancellation, recovery, and continuous improvement.
- Do not fake features.
- Do not leave visible buttons that do nothing.
- Do not create "coming soon" placeholders for launch features.
- Do not copy another application's branding, screenshots, icons, illustrations, or UI pixel-for-pixel.
- Use third-party source code only according to its license.
- Preserve all required license and NOTICE files.
- Audit every dependency before release.
- Do not upload files for features that are intended to be local.
- Do not require user registration or login.
- Do not use a WebView for the core app.
- Do not put heavy processing on the Android main thread.
- Do not load huge files entirely into RAM.
- Do not silently overwrite originals.
- Do not request unnecessary permissions.

---

# 1. PRODUCT PROMISE

Siliph:

"All-in-one PDF, image and document tools."

Secondary:

"Private. Fast. On your device."

Core principles:

1. No sign-in.
2. No account.
3. Local processing for supported tools.
4. No mandatory cloud.
5. No mandatory upload.
6. Fast startup.
7. Modern light UI.
8. Powerful tools hidden behind simple navigation.
9. Large-file safety.
10. Batch processing.
11. Strong accessibility.
12. Phone + tablet support.
13. Excellent Android integration.
14. Clear processing states.
15. Original files are protected.
16. Every tool has a clear input -> options -> process -> result workflow.

If a future feature genuinely requires network access, isolate it and clearly label it "Requires internet". Never pretend an online feature is offline.

---

# 2. PRIMARY SOURCE REPOSITORY

Use this repository as the primary starting point:

https://github.com/Karna14314/Pdf_Tools

Repository:
Karna14314/Pdf_Tools

It is an Apache-2.0 Android PDF toolkit and is useful as an engineering foundation.

FIRST ACTIONS:
1. Clone the repository.
2. Read LICENSE.
3. Read NOTICE.
4. Inspect every module.
5. Inspect Gradle files.
6. Inspect all dependencies.
7. Audit dependency licenses.
8. Build the original app.
9. Run existing tests.
10. Create a baseline feature inventory.
11. Create a baseline architecture report.
12. Record what already works.
13. Record what must be refactored.
14. Do not delete useful working functionality before understanding it.

The repository is a starting point, NOT the final Siliph product.

Do not simply rename the application and change the icon.

Create a new Siliph visual system and product architecture.

---

# 3. CURRENT MARKET FEATURE COVERAGE

Treat these as high-priority capabilities because current Android PDF/document apps are actively combining:
- PDF reading
- scanning
- OCR
- merge/split/compression
- signing
- forms
- conversion
- text-to-speech
- AI summaries/chat
- redaction
- document organization
- smart search
- Word/Office conversion
- on-device processing
- QR/barcode scanning
- reminders
- storage/file management

Do not add a feature just because a competitor has it. Every feature must be technically reliable and appropriate for the local-first product.

---

# 4. 2026 FLUTTER + ANDROID TECHNOLOGY BASELINE

Use the latest stable Flutter/Dart release that is compatible with the release date and all selected plugins. At the time this prompt is prepared, official Flutter documentation reflects Flutter 3.44.7. Verify the actual installed stable version before implementation instead of hardcoding an old version.

Official references to verify during implementation:
- Flutter Android integration: https://docs.flutter.dev/platform-integration/android
- Flutter Android release: https://docs.flutter.dev/deployment/android
- Android 16 setup: https://developer.android.com/about/versions/16/setup-sdk

Preferred stack:
- Flutter stable
- Dart stable compatible with that Flutter release
- Android API 36 compile/target baseline for the 2026 Android release
- Kotlin for native Android integration
- Gradle/Android Gradle Plugin versions required by the selected Flutter stable toolchain
- Material 3-inspired Flutter design system, but create a custom Siliph visual language rather than a stock Material app
- Riverpod or another lightweight, testable state-management solution; choose one and use it consistently
- go_router or a similarly robust declarative navigation solution
- freezed/json_serializable only where they materially improve correctness and maintainability
- drift/Isar/Hive/SQLite or another appropriate local database only after evaluating URI metadata and indexing needs; do not store large document bytes in the database
- shared_preferences only for tiny non-critical preferences; use a stronger structured local store where appropriate
- camera or a native CameraX bridge for the scanner; prefer CameraX for document scanning when Flutter camera plugins cannot provide required capabilities
- file_picker and/or Android SAF/Photo Picker integrations
- path_provider for app-owned directories
- share_plus or a native share bridge
- printing or Android printing APIs where appropriate
- image processing packages/native engines chosen after benchmark and license review
- PDF rendering/processing through a native Android bridge when Flutter-only packages cannot meet reliability/performance requirements
- Pigeon for typed Flutter <-> Kotlin APIs where a custom native bridge is needed
- Platform Channels only for small/simple APIs where Pigeon would be excessive
- FFI only when it materially improves access to a native/C/C++ processing engine and the maintenance cost is justified

IMPORTANT ARCHITECTURE RULE:
Flutter owns the product UI and application orchestration. Native Android owns performance-critical Android-specific document, camera, OCR, PDF, storage, and OS integrations when Flutter packages are insufficient. Do not force every operation into Dart. Do not force every UI feature into Kotlin.

Build configuration:
- compileSdk 36
- targetSdk 36
- choose minSdk based on actual plugin/engine support; target API 26+ if all P0 features remain reliable
- support Android 16 behavior changes and test target-SDK changes before release
- avoid hidden/non-SDK Android APIs
- use public Android SDK/NDK APIs

Do not blindly copy versions from the source repository or random tutorials. At project initialization, inspect current package versions, compatibility, licenses, changelogs, Android API support, and maintenance activity. Pin versions in the lockfile and document the decision.

Android 16 compatibility is a release requirement. Test compatibility changes, non-SDK API usage, background work, edge-to-edge/resizability behavior, predictive back, permissions, storage access, notifications, camera behavior, and large-screen behavior.

---

# 5. ARCHITECTURE

Use a Flutter-first modular architecture with a strict native boundary.

Recommended repository structure:

lib/
  app/
    app.dart
    router.dart
    theme/
    localization/
  core/
    constants/
    errors/
    logging/
    permissions/
    file/
    storage/
    platform/
    performance/
    security/
    analytics/
    utils/
  domain/
    models/
    repositories/
    usecases/
    services/
  data/
    local/
    repositories/
    datasources/
  engines/
    pdf/
    image/
    scanner/
    ocr/
    archive/
    conversion/
    ai/
  features/
    home/
    tools/
    search/
    pdf/
    reader/
    editor/
    image/
    scanner/
    ocr/
    documents/
    files/
    security/
    recent/
    settings/
  widgets/
    common/
    cards/
    dialogs/
    sheets/
    progress/
    previews/

android/app/src/main/kotlin/.../
  platform/
  pdf/
  scanner/
  ocr/
  storage/
  printing/
  sharing/
  background/

Architecture flow:

Flutter UI
-> Controller/ViewModel/Notifier
-> UseCase
-> Repository/Engine interface
-> Dart adapter OR typed native bridge
-> Native Android engine when required
-> file URI/path + result metadata
-> Flutter UI

NEVER pass 100s of MB of binary data through a MethodChannel/Pigeon call if the operation can instead pass a URI, path, descriptor, or temporary-file reference.

Native boundary rules:
1. Flutter passes source URI/path + options.
2. Native layer opens the source using ContentResolver/ParcelFileDescriptor or an app-owned temp file.
3. Native engine processes using streaming/random access where possible.
4. Native layer writes an output file.
5. Native layer emits typed progress.
6. Flutter receives output URI/path + metadata.
7. Flutter presents the result.

Use Pigeon for stable typed APIs such as:
- PdfProcessorApi
- ScannerApi
- OcrApi
- FileAccessApi
- PrintApi
- ShareApi
- BackgroundTaskApi

Keep the interfaces small and versionable.

---

# 6. TOOL REGISTRY

Create a central ToolDefinition model.

Example conceptual fields:

id
title
subtitle
category
icon
action
keywords
supportsBatch
requiresCamera
requiresNetwork
isFavorite
availability
sortPriority

This registry powers:
- Home quick actions
- Tool catalog
- Global search
- Categories
- Favorites
- Recent tools
- Suggested tools
- Contextual recommendations

Do not duplicate tool definitions in multiple screens.

Global tool search must be local and instant.

Search examples:

"compress"
-> Compress PDF
-> Compress Image
-> Exact KB Image
-> ZIP

"scan"
-> Document Scanner
-> QR Scanner
-> Barcode Scanner
-> OCR Scanner

---

# 7. COMPLETE FEATURE CATALOG

Implement launch-critical features first, then advanced features.

Use these priorities:

P0 = must work for launch
P1 = high-demand / important
P2 = advanced
P3 = optional / experimental

Never let P2/P3 destabilize P0.

---

# 8. PDF READER - P0

Build a premium PDF reader.

Features:
- open PDF
- smooth scrolling
- page jump
- page thumbnails
- pinch zoom
- double-tap zoom
- fit width
- fit page
- search text
- next/previous search result
- text selection
- copy
- share
- print
- bookmarks
- favorites
- recent documents
- document information
- page count
- file size
- orientation handling
- portrait/landscape
- tablet layout
- external "Open with" support
- Android share-sheet receive support

Optional reading modes:
- normal
- dim
- sepia
- night

Do not sacrifice rendering performance.

---

# 9. PDF ORGANIZATION - P0

Implement:

- Merge PDFs
- Split PDF
- Split by page range
- Split every N pages
- Extract pages
- Delete pages
- Reorder pages
- Rotate pages
- Insert pages
- Replace pages
- Duplicate pages
- Reverse page order
- Select specific pages
- Blank page insertion
- Extract selected pages as a new PDF

Use a thumbnail grid.

Support drag-and-drop page reordering.

Show clear selection states.

---

# 10. PDF COMPRESSION - P0

Implement:

- Low compression
- Medium compression
- High compression
- Custom
- Image quality
- DPI
- grayscale
- metadata removal
- optimization options

Before processing:
- estimate output size when practical
- estimate required storage
- validate file

After processing:
- validate resulting PDF
- compare size
- show savings
- verify it opens

Example:

18.4 MB
-> 4.7 MB
74% smaller

Never corrupt the original.

---

# 11. PDF EDITING - P0/P1

Implement where technically reliable:

- Add text
- Add image
- Draw
- Pen
- Highlighter
- Underline
- Strikeout
- Shapes
- Lines
- Arrows
- Sticky notes
- Eraser
- Whiteout
- Redaction
- Add signature
- Add initials
- Watermark
- Page numbers
- Date/time stamp
- QR code
- Stamps

Tools need:
- color
- opacity
- thickness
- size
- position
- rotation
- undo
- redo
- delete
- duplicate

Use AndroidX Ink or an appropriate drawing layer where practical.

---

# 12. PDF SIGNING - P0/P1

Signature workflow:

Create signature
-> draw
-> type
-> optionally import image
-> crop
-> remove background if reliable
-> save locally
-> reuse

On document:
- place
- resize
- rotate
- move
- delete

Do not call this a legally qualified digital signature unless the implementation actually provides the required certificate/signature infrastructure.

Use accurate terminology such as:
"electronic signature".

---

# 13. PDF FORMS - P1

Support where the PDF format permits:

- text fields
- checkboxes
- radio buttons
- dropdowns
- form reset
- save filled copy
- flatten form
- signature placement

Do not destroy the original form.

---

# 14. PDF SECURITY - P0/P1

Implement:

- password protection
- user password
- owner password where supported
- encryption
- unlock with supplied password
- metadata removal
- metadata editor

Never claim to "remove password" from a file without a valid password where encryption requires one.

---

# 15. PDF METADATA - P1

Read and edit:

- title
- author
- subject
- keywords
- creator
- producer
- creation date
- modification date where supported

Actions:
- remove all metadata
- edit metadata
- preview metadata

---

# 16. PDF CONVERSION - P0/P1

Implement locally where technically reliable:

- PDF -> JPG
- PDF -> PNG
- PDF -> WebP where appropriate
- JPG -> PDF
- PNG -> PDF
- WebP -> PDF
- multiple images -> one PDF
- text -> PDF
- TXT -> PDF
- HTML -> PDF where reliable

Advanced conversion:
- PDF -> DOCX
- DOCX -> PDF
- PDF -> XLSX/CSV where the document structure allows it
- Office -> PDF

IMPORTANT:
Do not pretend arbitrary DOCX/PDF fidelity is perfect.
If a conversion engine cannot reliably run locally, either:
1. implement a reliable subset, or
2. explicitly mark it as an optional online feature.

Never create a fake converter.

---

# 17. PDF TOOLS - P1/P2

Add:

- PDF page numbering
- PDF header/footer
- PDF crop pages
- PDF resize pages
- PDF booklet/imposition where reliable
- N-up pages
- 2 pages per sheet
- 4 pages per sheet
- print layout
- flatten annotations
- optimize PDF
- repair PDF where technically possible
- PDF/A conversion where reliable
- PDF properties viewer

---

# 18. OCR - P0

Build a modular OCR engine.

Interface:

OcrEngine

Capabilities:
- image OCR
- scanned PDF OCR
- page OCR
- region OCR
- copy text
- edit extracted text
- search OCR text
- export TXT
- export JSON
- create searchable PDF

Preferred options:
- ML Kit
- ONNX Runtime
- Tesseract/PaddleOCR where justified

Do not require internet for the selected local OCR implementation.

Do not bundle unnecessary huge models.

If models are optional downloads:
- explain size
- show progress
- allow cancellation
- keep processing local
- clearly explain where models are stored

---

# 19. OCR LANGUAGES - P1

Design the OCR system so languages can be added modularly.

Start with:
- English
- Hindi
- Bengali

Then support additional languages according to engine/model availability and licensing.

Do not claim language support unless the engine actually recognizes that language reliably.

---

# 20. DOCUMENT SCANNER - P0

Use CameraX.

Features:

- live camera
- document edge detection
- automatic capture
- manual capture
- perspective correction
- auto crop
- manual corner adjustment
- rotate
- brightness
- contrast
- sharpen
- black/white
- grayscale
- color
- document enhancement
- multi-page scan
- page reorder
- delete pages
- retake
- import from gallery
- scan to PDF
- scan to JPG
- OCR

Scanner modes:

- Document
- Receipt
- ID card
- Passport
- Business card
- Book
- Photo

---

# 21. BOOK SCANNER - P2

Add:
- two-page capture
- curved-page correction where reliable
- page splitting
- background cleanup
- shadow reduction
- book mode
- page numbering

Do not implement aggressive image transformations that damage text.

---

# 22. IMAGE TOOLS - P0

Implement:

Compression:
- compress
- exact KB
- exact MB
- quality slider
- target dimension
- batch compression

Exact targets:
20 KB
50 KB
100 KB
200 KB
250 KB
500 KB
1 MB
2 MB
custom

Formats:
- JPG
- PNG
- WebP
- HEIC
- BMP
- TIFF where supported

Operations:
- resize
- crop
- rotate
- flip
- image -> PDF

---

# 23. EXACT IMAGE SIZE ALGORITHM

Create a robust compressor.

Inputs:
- source image
- target bytes
- min quality
- max quality
- optional dimensions

Algorithm:
1. decode safely/downsample if needed
2. normalize orientation
3. estimate output
4. encode
5. measure actual bytes
6. adjust quality
7. retry using bounded binary search
8. if necessary adjust dimensions
9. stop within configured tolerance
10. validate output
11. never output corrupt image

Show:
Original
Target
Actual
Quality
Dimensions

If exact target is impossible:
show the closest safe output and explain why.

---

# 24. IMAGE EDITOR - P1

Implement:

- crop
- resize
- rotate
- flip
- brightness
- contrast
- saturation
- exposure
- sharpness
- blur
- pixelate
- draw
- text
- shapes
- watermark
- background color
- undo
- redo

Use non-destructive editing where practical.

Do not decode massive source images repeatedly.

---

# 25. IMAGE METADATA - P1

Implement:
- EXIF viewer
- remove EXIF
- remove GPS
- remove device info
- remove metadata
- metadata preview

Warn before removing metadata if the user might need it.

---

# 26. IMAGE BATCH PROCESSING - P0

Allow:
- 1
- 10
- 50
- 100+
images where device resources allow

Batch actions:
- compress
- exact target size
- resize
- convert
- remove metadata
- rename
- export

Show:
- overall progress
- current file
- successful count
- failed count
- cancelled count

Partial success is acceptable.

Do not fail the entire batch because one file fails.

---

# 27. PASSPORT / ID PHOTO - P1

Add a dedicated image tool:

- common passport dimensions
- custom dimensions
- background color
- crop
- face positioning guide
- multiple copies on one printable page
- export JPG
- export PDF

Do not claim a photo is officially compliant for a government process unless the actual dimensions/rules are known and selected by the user.

---

# 28. SIGNATURE MAKER - P1

Create:
- draw signature
- type signature
- import signature
- crop
- clean background
- resize
- export transparent PNG where technically possible
- save multiple signatures locally

---

# 29. QR / BARCODE - P1

Scanner:
- QR
- barcode

Generator:
- text
- URL
- Wi-Fi
- contact/vCard
- email
- phone
- SMS

Save as:
- PNG
- SVG where supported

Keep scanning local.

---

# 30. DOCUMENT MANAGEMENT - P1

Create local document library.

Features:
- recent
- favorites
- folders
- tags
- search
- sort
- filter
- grid/list
- file type filter
- date filter
- size filter
- share
- rename
- delete
- move
- copy
- open with

Do not copy file contents into a database.

Store URI/path metadata.

---

# 31. SMART SEARCH - P1

Search:
- filename
- folder
- file type
- date
- size
- tags

Optional OCR content search:
- search extracted OCR text
- search document metadata

Advanced semantic search is optional and should only be implemented if a suitable on-device model is small and performant enough.

---

# 32. SMART FOLDERS - P2

Automatically categorize:
- Scans
- PDFs
- Images
- Signed
- Receipts
- IDs
- Forms
- Recent

Allow manual folders.

Keep all indexing local.

---

# 33. DOCUMENT REMINDERS - P2

Optional local reminders:
- document expiration
- passport renewal
- bill
- submission
- contract review

Use Android local notifications.

Do not upload documents.

Do not scan sensitive document contents automatically just to create reminders.

---

# 34. FILE UTILITIES - P1

Implement:

- file information
- rename
- copy
- move
- delete
- share
- open with
- recent
- favorites
- file size
- MIME type
- modified date

---

# 35. ARCHIVE TOOLS - P1

Implement:
- ZIP create
- ZIP extract
- archive browsing
- selected-file extraction
- batch archive

Optional:
- encrypted ZIP where reliable

Do not call a destructive "shredder" secure deletion feature unless the implementation is technically defensible on modern flash storage. Prefer normal deletion and clear privacy wording.

---

# 36. STORAGE ANALYZER - P2

Show:
- total storage
- used
- free
- Siliph cache
- large files
- file type breakdown

Do not scan entire storage without user consent.

Use system-provided storage information where possible.

---

# 37. DUPLICATE FINDER - P2

Implement:
- exact duplicate detection
- SHA-256 hash
- size-first filtering
- user-selected folders

Never delete automatically.

Show:
Original
Duplicate
Size
Location

User must explicitly choose deletion.

---

# 38. PDF REDACTION - P1

Implement real redaction, not just drawing a black rectangle.

Workflow:
select region
-> mark for redaction
-> preview
-> apply permanently
-> validate

Explain:
"Redaction permanently removes the selected content from the output."

Never claim a visual overlay is secure redaction.

---

# 39. QR CODE IN PDF - P2

Allow:
- QR code creation
- placement
- resize
- rotation
- color
- content
- preview

---

# 40. PDF TEXT-TO-SPEECH - P2

Allow:
- read current page
- read from current position
- pause
- resume
- speed
- voice selection through Android TTS
- skip headings/pages where detectable

Do not require a cloud voice.

Use Android system TTS where possible.

---

# 41. AI FEATURES - P2/P3

AI is optional and must not break the local-first product.

Preferred order:

A. On-device AI first.
B. Optional user-enabled online AI second.

Possible features:
- summarize PDF
- extract key points
- ask questions about document
- find dates
- find names
- find emails
- find phone numbers
- count words
- translate OCR text
- improve OCR formatting
- generate flashcards
- generate quiz questions

IMPORTANT:
If an online AI API is used:
- explicit user action required
- clear network label
- explain that document content is being sent
- no background uploads
- no hidden telemetry
- API key must never be embedded as a secret in the client
- do not make AI mandatory for core PDF features

If the user requires strict offline mode:
AI features should be disabled or use the selected on-device model.

---

# 42. AI DOCUMENT CHAT

If implemented:

UI:
document preview + chat

Actions:
- summarize
- ask question
- extract table
- find clause
- explain page
- create checklist

Citations:
Every AI answer should show the source page(s) when the engine can reliably determine them.

Never present unsupported guesses as document facts.

Add:
"AI can make mistakes. Check the source document."

---

# 43. TABLE EXTRACTION - P2

Where technically reliable:
- detect tables
- preview table
- edit cells
- export CSV
- export TSV
- export XLSX where library/license permits

Do not promise perfect table reconstruction from arbitrary PDFs.

---

# 44. OFFICE CONVERSION - P2

Evaluate suitable local engines/libraries for:
- DOCX -> PDF
- PDF -> DOCX
- XLSX -> PDF
- PPTX -> PDF

If local conversion is not reliable or library licensing is unsuitable:
- do not fake it
- isolate it as an optional online feature
- label clearly

---

# 45. SHARE / INTENTS - P0

Support:
- Android share sheet
- SEND
- SEND_MULTIPLE
- VIEW
- OPEN_DOCUMENT
- CREATE_DOCUMENT

Siliph should be able to:
- open PDF from WhatsApp
- open PDF from Gmail
- open image from gallery
- receive files from other apps
- share outputs to other apps

---

# 46. PRINT - P1

Use Android printing APIs where appropriate.

Support:
- system print dialog
- PDF print
- image print

Do not directly integrate vendor-specific printers unless a reliable SDK is required.

---

# 47. HOME SCREEN

Default light theme.

Design:

Header:
Siliph logo
Siliph
Settings

Hero:
"All-in-one File Tools"
"Private. Fast. On your device."

Global search:
"Search tools..."

Category cards:
PDF
Images
Scanner
OCR
Files

Quick actions:
Merge PDF
Compress PDF
Scan
JPG -> PDF
Compress Image
OCR

Recent files.

Favorites.

Suggested tools.

No empty home screen.

If there is no history:
show a useful action-oriented empty state.

---

# 48. TOOLS SCREEN

Tabs/chips:
All
PDF
Images
Scanner
OCR
Documents
Files
Security
Utilities
AI

Grid:
4 columns on large phones/tablets where appropriate
2 columns on smaller phones

Each card:
icon
name
short description
favorite

Use lazy layouts.

---

# 49. BOTTOM NAVIGATION

Phone:

Home
Tools
center "+"
Recent
Settings

Center "+" opens:
- Scan
- Pick PDF
- Pick Images
- Pick Files

Tablet:
use NavigationRail / adaptive navigation.

---

# 50. TOOL SCREEN STANDARD

Every tool must have:

Top app bar
Back
Title
Favorite

Input
Preview
Options
Advanced settings
Primary CTA
Privacy/status note

No confusing workflows.

Use one primary action per screen.

---

# 51. PROCESSING UI

Show:

Preparing...
Processing...
Finalizing...
Validating...

Progress:
percentage
current page/file
elapsed
estimated remaining time when reliable

Buttons:
Cancel

Never freeze the UI.

Cancellation must actually stop work where the engine permits.

---

# 52. RESULT UI

Large success indicator.

Example:

Done

Original:
18.4 MB

Output:
4.7 MB

Saved:
74%

Buttons:
Open
Share
Save As
Process Another

Small:
"Processed on your device."

---

# 53. ERROR UI

Example:

"Couldn't finish"

Reason:
"The file appears to be damaged or uses an unsupported feature."

Buttons:
Try Again
Choose Another File
Report Problem

Small:
"Your original file was not changed."

Never expose stack traces.

---

# 54. LIGHT UI DESIGN SYSTEM

Default:
Light theme.

Visual language:
- white/off-white background
- Siliph purple primary
- near-black text
- neutral gray secondary text
- subtle borders
- soft shadows
- restrained gradients
- high contrast

Create:
SiliphColors
SiliphTypography
SiliphShapes
SiliphSpacing
SiliphMotion
SiliphElevation

Do not hardcode UI colors.

Avoid:
- excessive glassmorphism
- huge gradients
- excessive pills
- tiny text
- clutter
- giant empty spaces
- excessive animation

---

# 55. ICONS

Use:
- Material Symbols where suitable
- custom Siliph vector icons for branded tools

Create a consistent icon family.

Do not use emoji as production tool icons.

Do not use copyrighted icons.

---

# 56. GRAPHICS

Create original lightweight vector illustrations for:
- empty state
- success
- error
- scanner
- PDF
- image compression
- privacy
- no files
- storage

Avoid remote image dependencies for core UI.

---

# 57. ANIMATION

Use Flutter animation primitives and keep animation logic separate from business logic.

Use:
- AnimatedSwitcher
- AnimatedSize
- AnimatedContainer only where appropriate
- implicit animations for small state changes
- AnimationController for controlled motion
- Hero only when it materially improves navigation
- CustomPainter only when necessary
- slivers for performant scrolling

Implement:
- screen transitions
- card press feedback
- favorite animation
- search expansion
- tool selection
- progress transition
- success animation
- error animation
- scanner capture feedback
- page drag/reorder feedback
- bottom sheets
- image comparison slider
- result reveal
- skeleton/loading states only when they communicate real work

Rules:
- fast
- subtle
- interruptible
- no animation should delay a usable action
- 60fps target
- high-refresh displays should remain smooth
- honor reduced-motion/accessibility preferences
- avoid expensive blur/backdrop filters on large scrolling surfaces
- never animate hundreds of document thumbnails simultaneously

---

# 58. IMAGE COMPRESSION PREVIEW

Use an interactive before/after slider.

Show:
Original size
Compressed size
Savings

Do not run expensive full-resolution processing on every slider movement.

Use:
- preview resolution
- debounce
- background processing

---

# 59. SCANNER CAMERA UX

Top:
Back
Flash
Settings

Center:
document boundary

Bottom:
gallery
capture
page count

After capture:
crop
rotate
enhance
filter
OCR
add page
finish

Add subtle haptic feedback.

---

# 60. STORAGE / FILE ACCESS

Use:
- Android Photo Picker
- ACTION_OPEN_DOCUMENT
- ACTION_OPEN_DOCUMENT_TREE when necessary
- ACTION_CREATE_DOCUMENT
- ContentResolver
- persistable URI permissions

Avoid broad storage permissions.

Do not request all files access unless there is an exceptional, documented reason and Play policy permits it.

---

# 61. DATABASE

Room entities:

RecentFile
FavoriteTool
FavoriteFile
ProcessingHistory
SavedPreset
DocumentFolder
DocumentTag
Signature
ScanSession
Reminder

Do not store large file bytes in Room.

Use URI references.

---

# 62. DATASTORE

Store:
- theme
- default save location
- compression preset
- image quality
- haptics
- keep screen on
- selected language
- onboarding state
- reader preferences

---

# 63. LARGE FILE ARCHITECTURE

Critical requirement.

Test:
1 MB
10 MB
50 MB
100 MB
250 MB
500 MB
1 GB where device permits

Never:
- read entire PDF into one ByteArray
- decode every page simultaneously
- hold hundreds of full-resolution bitmaps
- use base64 for large files

Use:
- streaming
- random access
- page/chunk processing
- bounded concurrency
- downsampling
- thumbnail cache
- temporary files
- incremental output

Before large operation:
check free storage.

---

# 64. MEMORY MANAGEMENT

Rules:
- heavy work off main thread
- release Bitmap references
- use sampled decoding
- use bounded worker pools
- avoid unnecessary copies
- avoid nested huge collections
- use file streams
- clear temporary caches
- cancel promptly

Add instrumentation for memory usage on large-file tests.

---

# 65. BATCH ENGINE

Create:

BatchProcessor

State:
Idle
Preparing
Processing
Cancelling
Completed
PartialSuccess
Failed

Per item:
Queued
Processing
Success
Failed
Cancelled

Support:
- retry failed
- cancel all
- continue successful items
- export successful results

---

# 66. BACKGROUND PROCESSING

Use WorkManager only when appropriate.

For user-visible long operations:
- foreground service only when justified by current Android restrictions and UX requirements
- otherwise keep processing lifecycle-aware

Do not abuse background execution.

---

# 67. NOTIFICATIONS

For long operations:
- progress notification when appropriate
- completion notification
- failure notification

User can disable notifications.

Do not spam.

---

# 68. ACCESSIBILITY

Support:
- TalkBack
- content descriptions
- semantic roles
- scalable fonts
- contrast
- minimum touch targets
- reduced motion
- keyboard navigation where relevant

Never rely only on color to communicate state.

---

# 69. TABLET / LARGE SCREEN

Use adaptive layouts.

Phone:
bottom navigation.

Tablet:
navigation rail/sidebar.

PDF reader:
page thumbnails + document view + tools panel.

Editor:
canvas + tools.

Scanner:
camera + controls.

Do not simply stretch phone UI.

---

# 70. OFFLINE-FIRST

Core features must work with airplane mode:

- merge
- split
- rotate
- extract
- delete pages
- reorder
- PDF reader
- image compression
- image resize
- image conversion
- scan
- OCR where local engine/model is installed
- sign
- watermark
- metadata
- ZIP

Test the app with network disabled.

If a dependency unexpectedly attempts network access, investigate it.

---

# 71. PRIVACY

Never:
- upload documents silently
- log document contents
- log sensitive filenames unnecessarily
- send OCR text to analytics
- send PDF text to analytics
- collect unnecessary identifiers

Use secure temporary directories.

Delete temporary files.

Show:
"Your files stay on your device for local processing."

Do not make false privacy claims.

---

# 72. SECURITY

Use Android Keystore for any locally stored secrets.

Optional encrypted local vault can be added later.

Do not implement insecure custom encryption.

If a vault is implemented:
- use modern authenticated encryption
- use hardware-backed Keystore where available
- clearly document device limitations
- never claim that deleting a file from flash storage guarantees physical destruction

---

# 73. LOCAL DOCUMENT VAULT - P2

Optional:
- private vault
- biometric unlock
- device credential unlock
- encrypted files
- lock timeout
- hide from recent list

Keep it completely local.

Do not make vault recovery depend on a server.

Warn users that forgetting the credential may make data unrecoverable.

---

# 74. PERFORMANCE BENCHMARKING

Create benchmark tests for:
- app startup
- PDF open
- PDF first page render
- thumbnail generation
- merge
- split
- compression
- image compression
- OCR
- scan processing

Record:
- time
- memory
- output size

Use benchmarks to prevent regressions.

---

# 75. TEST FILE CORPUS

Create test fixtures:

PDF:
- small
- large
- encrypted
- malformed
- image-heavy
- text-heavy
- scanned
- forms
- annotations
- different page sizes
- rotated pages
- Unicode text

Images:
- JPG
- PNG
- WebP
- HEIC
- huge resolution
- EXIF
- transparent
- malformed

Scanner:
- receipts
- books
- IDs
- skewed pages
- shadows
- low light
- handwriting
- multi-page

Do not include copyrighted private documents in the repository.

Use synthetic/generated test fixtures.

---

# 76. AUTOMATED TESTS

Unit tests:
- page selection
- page ranges
- compression
- exact-size algorithm
- metadata
- file naming
- URI handling
- cancellation
- batch
- error mapping

Integration tests:
- PDF engine
- image engine
- OCR
- storage
- Room

Flutter widget/integration tests:
- Home
- Tools
- Search
- PDF workflow
- Image workflow
- Scanner
- Settings
- Success
- Error

Screenshot tests:
- light theme
- different font sizes
- phone
- tablet

---

# 77. DEVICE TEST MATRIX

Test:
Android 8+
Android 10
Android 11
Android 12
Android 13
Android 14
Android 15
Android 16

Test:
- low RAM
- normal RAM
- high RAM
- low storage
- large storage
- slow CPU
- fast CPU
- portrait
- landscape
- tablet

---

# 78. CRASH / FAILURE STRATEGY

Before every operation:
validate.

During:
progress + cancellation.

After:
validate output.

If failure:
- preserve original
- clean temporary files
- show useful message
- offer retry
- optionally collect local diagnostic info only after user action

Do not automatically upload crash logs containing document information.

---

# 79. APP STARTUP

Target:
fast cold start.

Do not:
- initialize every engine at startup
- load OCR models at startup
- scan entire storage at startup
- build thumbnails for every file at startup
- initialize camera at startup

Lazy-load heavy components.

---

# 80. HOME PERFORMANCE

Use:
LazyColumn
LazyVerticalGrid
stable models
derived state
thumbnail cache

Do not load full documents for recent-file cards.

Use lightweight metadata and thumbnails.

---

# 81. FAVORITES

Users can favorite:
- tools
- documents
- signatures
- folders

Favorites stored locally.

---

# 82. RECENT HISTORY

Store:
- file name
- URI
- operation
- time
- result URI
- status

Never store document contents.

If URI becomes invalid:
show "File no longer available."

---

# 83. SETTINGS

Sections:

Appearance
- Theme
- Light default
- Dark
- System
- Accent if offered

Processing
- PDF quality
- image quality
- default output
- keep original
- keep screen on

Storage
- save location
- cache
- clear cache

Privacy
- local processing
- permissions
- clear history

Accessibility
- reduced motion
- text size guidance

General
- language
- haptics
- notifications

About
- version
- licenses
- privacy policy
- terms
- feedback

---

# 84. ONBOARDING

Maximum 3 screens.

1:
"Your files stay on your device."

2:
"PDF, images, scanning and OCR in one app."

3:
"No account required."

Skip button.

Never block the user with registration.

---

# 85. FIRST RUN PERMISSIONS

Do not ask for camera on first launch.

Ask camera permission only when scanner is opened.

Use system file/photo pickers.

Explain why permission is needed.

---

# 86. LOCALIZATION

Prepare strings.xml / Flutter localization properly.

Do not hardcode UI strings.

Initial:
English
Hindi
Bengali

Add more later.

Do not translate technical error messages incorrectly.

---

# 87. SEARCH UX

Global search:
- instant
- fuzzy matching
- keyword matching
- recent searches optional
- categories
- tool aliases

Examples:
"reduce pdf"
-> Compress PDF

"make photo smaller"
-> Compress Image

"scan paper"
-> Document Scanner

"convert picture to pdf"
-> Image to PDF

---

# 88. SMART TOOL RECOMMENDATIONS

Use local rules.

Example:
If user opens large PDF:
suggest Compress PDF.

If user imports many images:
suggest Images -> PDF or Batch Compress.

If scan contains text:
suggest OCR.

Do not need cloud AI.

---

# 89. FILE NAME GENERATION

Create safe output names:

Original:
report.pdf

Outputs:
report_compressed.pdf
report_merged.pdf
report_split_01.pdf
report_signed.pdf

Avoid overwriting.

Handle duplicate names.

---

# 90. OUTPUT VALIDATION

Every generated output should be validated when practical.

PDF:
- can reopen
- page count
- basic structure

Image:
- decodes successfully
- correct dimensions
- expected format
- expected file size

ZIP:
- can reopen
- expected entries

OCR:
- text exists where expected

---

# 91. CANCELLATION

Every expensive operation should accept cancellation.

If cancelled:
- stop work
- delete incomplete output
- preserve original
- return to safe state

Do not leave corrupt partial files in the user's output folder.

---

# 92. FILE LOCKING / CONCURRENCY

Prevent:
- same file being modified by two operations
- simultaneous conflicting writes

Allow safe parallel operations where inputs/outputs are independent.

---

# 93. REAL-TIME PROGRESS

Use StateFlow.

Example:

ProcessingState(
  phase,
  currentItem,
  currentPage,
  completed,
  total,
  percent,
  elapsed,
  estimatedRemaining,
  outputBytes
)

Do not fake progress.

If exact progress is unavailable:
show an indeterminate progress indicator rather than inventing a percentage.

---

# 94. AI CODING WORKFLOW

You are an AI coding agent.

Do not try to implement the entire application in one huge change.

Work in phases.

After each phase:
1. inspect
2. implement
3. compile
4. run tests
5. run lint
6. inspect errors
7. fix
8. verify
9. summarize changes
10. continue

Never move to the next phase while the current phase has known build-breaking errors.

---

# 95. PHASE-BY-PHASE BUILD PLAN

PHASE 0: PRODUCT + REPOSITORY AUDIT
- inspect the uploaded/current source prompt and project requirements
- clone the primary PDF repository
- build the original Android project
- inspect LICENSE/NOTICE
- inspect modules and dependencies
- map reusable processing code
- identify code that is UI-only and should not be migrated
- create dependency/license matrix
- create feature matrix
- create risk register

PHASE 1: FLUTTER PROJECT FOUNDATION
- create Flutter stable project
- configure Android target/compile SDK 36
- set application ID
- app name Siliph
- launcher icon
- splash screen
- flavors if needed
- environment configuration
- lint/analyzer
- formatting
- CI skeleton

PHASE 2: DESIGN SYSTEM + APP SHELL
- light theme first
- typography
- spacing
- colors
- shapes
- elevations
- icon system
- animations
- adaptive navigation
- Home
- Tools
- Recent
- Settings

PHASE 3: FILE INFRASTRUCTURE
- URI model
- SAF bridge
- Photo Picker
- file import
- export/save-as
- share intents
- file metadata
- permissions
- temporary workspace

PHASE 4: NATIVE BRIDGE FOUNDATION
- Pigeon setup
- typed API definitions
- Kotlin implementations
- progress events
- cancellation tokens
- error mapping
- output URI contracts
- bridge integration tests

PHASE 5: PDF ENGINE
- PdfEngine interface
- inspect/adapt reusable source code
- PDF validation
- page thumbnails
- rendering
- page manipulation
- reader
- search

PHASE 6: PDF CORE TOOLS
- merge
- split
- extract
- delete
- reorder
- rotate
- insert
- replace
- duplicate
- reverse

PHASE 7: PDF COMPRESSION + SECURITY
- compression
- optimization
- password protection
- unlock with valid password
- metadata
- watermark
- flatten

PHASE 8: PDF EDITOR
- annotations
- text
- images
- shapes
- signatures
- forms
- redaction
- page numbers

PHASE 9: IMAGE ENGINE
- decode safely
- resize
- crop
- rotate
- flip
- format conversion
- metadata
- compression

PHASE 10: EXACT-SIZE + BATCH IMAGE ENGINE
- target-byte compression
- bounded search algorithm
- preview
- batch queue
- partial failures
- cancellation

PHASE 11: SCANNER
- CameraX/native camera where required
- Flutter scanner UI
- edge detection
- auto capture
- manual capture
- perspective correction
- enhancement
- multi-page

PHASE 12: OCR
- OcrEngine interface
- ML Kit/local engine evaluation
- optional Tesseract/ONNX where licensing/performance permits
- English/Hindi/Bengali evaluation
- searchable PDF
- text export

PHASE 13: DOCUMENT LIBRARY
- Room/native or Flutter local DB decision
- recent
- favorites
- folders
- tags
- search
- filters
- smart folders

PHASE 14: FILE + ARCHIVE TOOLS
- ZIP
- file info
- rename
- move/copy
- delete
- storage analyzer
- duplicate finder

PHASE 15: UTILITIES
- QR/barcode scanner
- QR generator
- signature maker
- passport/ID photo
- printing
- reminders

PHASE 16: ADVANCED DOCUMENT FEATURES
- table extraction
- DOCX/Office conversion where reliable
- text-to-speech
- PDF/A/booklet/N-up where reliable

PHASE 17: OPTIONAL AI
- on-device feasibility study
- summarization
- document Q&A
- extraction
- translation
- page citations
- online AI isolation if explicitly enabled

PHASE 18: PERFORMANCE
- startup
- large files
- memory
- thumbnail cache
- isolate/native processing
- bridge overhead
- battery

PHASE 19: POLISH
- animations
- haptics
- accessibility
- responsive layouts
- tablet/foldable
- empty/error/success states

PHASE 20: TESTING
- Dart unit tests
- Flutter widget tests
- integration tests
- native Kotlin tests
- golden/screenshot tests
- performance benchmarks
- large-file tests
- offline tests

PHASE 21: SECURITY + PRIVACY
- permission audit
- network audit
- telemetry audit
- secrets audit
- temp file cleanup
- dependency/license audit
- Play policy review

PHASE 22: RELEASE
- release signing
- R8
- AAB
- internal testing
- closed testing
- Play listing
- privacy policy
- Data Safety
- content rating

PHASE 23: RELEASE CANDIDATE
- clean clone build
- offline mode
- regression suite
- device matrix
- performance gates
- final UX review
- final source/license audit

---

# 96. AI SELF-REVIEW AFTER EACH PHASE

At the end of every phase, produce:

## Completed
list

## Changed files
list

## Tests
list

## Build status
PASS/FAIL

## Known issues
list

## Performance impact
list

## License impact
list

## Next phase
one clear next step

Do not hide failures.

---

# 97. USER FEEDBACK LOOP

When the user gives feedback such as:

- "button is too small"
- "screen is empty"
- "animation is bad"
- "app is slow"
- "this feature doesn't work"
- "PDF crashes"
- "scanner crop is inaccurate"
- "UI doesn't look premium"

Do NOT merely patch the screenshot.

Instead:
1. identify root cause
2. inspect related architecture
3. fix reusable components
4. add regression test if possible
5. rebuild
6. verify the affected workflow
7. verify adjacent workflows
8. report exactly what changed

Example:

User says:
"Compress PDF is slow."

Do:
- benchmark
- profile
- inspect rendering
- inspect bitmap allocation
- reduce unnecessary decoding
- stream processing
- optimize concurrency
- test large PDF
- compare before/after

Do not simply add a spinner.

---

# 98. UI FEEDBACK LOOP

When the user gives a screenshot:
- inspect spacing
- typography
- hierarchy
- alignment
- touch targets
- component consistency
- visual density
- contrast
- animation opportunities

Then make reusable design-system changes rather than one-off hacks.

Never leave one screen visually inconsistent with the rest.

---

# 99. NO PLACEHOLDERS

Before release, search the source for:
TODO
FIXME
Coming soon
Not implemented
Placeholder
Mock
Fake
Sample data

Any remaining item must be reviewed.

Visible launch features must be functional.

---

# 100. SOURCE CODE QUALITY

Dart/Flutter:
- sound null safety
- immutable state where practical
- const constructors where beneficial
- small widgets
- reusable components
- clear naming
- testable use cases
- avoid build-method business logic
- avoid unnecessary rebuilds
- use keys deliberately for lists/reorderable content
- dispose controllers, streams, subscriptions, and native resources
- avoid unbounded streams and timers

Kotlin native layer:
- Kotlin idioms
- lifecycle-aware code
- structured concurrency where appropriate
- small typed APIs
- no UI logic in processing engines
- no static global state for mutable document state
- safe ContentResolver usage
- close ParcelFileDescriptor/InputStream/OutputStream resources

Avoid:
- god widgets
- god services
- duplicated business logic
- giant state objects that trigger full-screen rebuilds
- memory-heavy helpers
- unnecessary dependencies
- direct engine calls from widgets
- platform-channel strings scattered throughout the app
- hard-coded file paths
- hard-coded Android package-specific assumptions

---

# 101. LICENSE / OPEN SOURCE RULES

For every external repository:
- identify license
- check compatibility
- preserve required notices
- record source URL
- record version/commit
- record modifications

Avoid GPL/AGPL dependencies if the intended distribution model cannot satisfy their copyleft requirements.

Do not copy code from repositories with unclear licensing.

Do not copy proprietary competitor assets.

---

# 102. GOOGLE PLAY PREPARATION

Prepare:
- AAB
- release signing
- adaptive icon
- screenshots
- feature graphic
- short description
- full description
- privacy policy
- Data Safety form
- content rating
- app category

Ensure all store claims match actual implementation.

Do not claim:
- 100% offline if any listed feature needs network
- zero bugs
- perfect conversion
- guaranteed OCR accuracy
- guaranteed government-form compliance
- secure deletion from flash storage

---

# 103. FINAL PRODUCT NAVIGATION

Home
Tools
+
Recent
Settings

Tools:
PDF
Images
Scanner
OCR
Documents
Files
Security
Utilities
AI

---



---

# 107. FLUTTER PROJECT RULES

Create a genuine Flutter Android application.

Do NOT:
- create a WebView wrapper
- put the existing Android app inside a WebView
- recreate the entire app as HTML
- use Flutter only as a launcher for an unrelated native UI
- move huge PDF/image bytes through Dart/native messages

Flutter must own:
- navigation
- screens
- components
- animations
- theme
- user interaction
- tool discovery
- progress/result UI
- settings
- document library presentation

Native Android may own:
- PDF processing
- PDF rendering when required
- CameraX
- OCR engines
- image codecs/processing where required
- SAF edge cases
- printing
- background processing
- Android-specific security
- platform APIs not adequately exposed by Flutter packages

---

# 108. FLUTTER PACKAGE SELECTION RULE

Before adding a package, create a package decision record:

Package:
Purpose:
Version:
Repository:
License:
Last meaningful maintenance:
Android API support:
Flutter stable compatibility:
Known issues:
Alternatives:
Why selected:

Prefer:
1. official Flutter/Dart packages when suitable
2. AndroidX/native APIs through a maintained bridge
3. mature, actively maintained community packages
4. custom implementation only when necessary

Do not add packages merely because an AI coding agent suggests them.

Avoid dependency sprawl.

Every package must have a reason to exist.

---

# 109. NATIVE BRIDGE CONTRACT

Define native APIs as typed operations.

Example conceptual contract:

PdfProcessRequest:
- operation
- inputUri
- outputUri
- options

PdfProcessProgress:
- jobId
- phase
- current
- total
- percent
- message

PdfProcessResult:
- success
- outputUri
- outputBytes
- pageCount
- warnings

PdfError:
- code
- userMessage
- recoverable
- detailsForDiagnostics

Do not expose raw exceptions to Flutter UI.

Map errors into stable application-level error codes.

Example:
INVALID_INPUT
PASSWORD_REQUIRED
PASSWORD_INCORRECT
UNSUPPORTED_PDF
CORRUPT_FILE
NO_STORAGE
CANCELLED
PERMISSION_DENIED
OUTPUT_VALIDATION_FAILED
PROCESSING_FAILED
UNSUPPORTED_FEATURE

---

# 110. BRIDGE PERFORMANCE RULES

Never send:
- entire PDF as Uint8List for a 100 MB+ document
- full-resolution image repeatedly across the bridge
- thousands of thumbnails in one message

Send:
- URI
- path to app-owned temporary file
- small metadata
- options
- progress

For previews:
- create bounded thumbnails
- cache them
- send only the preview needed by the current screen

---

# 111. FLUTTER STATE MANAGEMENT

Choose one primary state-management architecture and use it consistently.

Recommended:
- Riverpod

Rules:
- business state does not live inside random widgets
- controllers own workflow state
- repositories own data access
- engines own processing
- UI observes immutable state
- cancel/dispose jobs when the screen no longer needs them

Avoid:
- global mutable singletons for document state
- calling processing engines directly from build()
- starting asynchronous work repeatedly during rebuilds
- storing huge byte arrays in global state

---

# 112. NAVIGATION

Use declarative routing.

Routes should include:
/
/tools
/tools/pdf
/tools/images
/tools/scanner
/tools/ocr
/tools/files
/reader/:id
/editor/:id
/process/:jobId
/result/:jobId
/settings

Support:
- Android back
- predictive back where supported
- deep links where useful
- state restoration
- process death recovery for safe metadata

Do not persist sensitive document content just to restore a screen.

---

# 113. ADAPTIVE UI

The application must work on:
- small phones
- normal phones
- large phones
- foldables
- tablets
- split-screen
- landscape

Do not hard-code one phone width.

Use LayoutBuilder/MediaQuery and adaptive navigation.

At larger widths:
- navigation rail/sidebar
- multi-column tool grids
- PDF thumbnails beside document
- editor tools beside canvas
- scanner controls arranged for landscape

Test at several logical widths.

---

# 114. HOME UI SPECIFICATION

Home must be useful immediately.

Top:
- Siliph logo
- greeting/product label
- settings

Search field:
"What do you want to do?"

Popular tools:
- Compress PDF
- Merge PDF
- Scan Document
- Compress Image
- JPG to PDF
- OCR

Categories:
PDF
Image
Scanner
OCR
Files
Security
Utilities
AI

Recent files:
- thumbnail/icon
- filename
- time
- file type

If empty:
show action cards, not blank whitespace.

Example empty state:
"Start with a file"
"Scan a document, choose a PDF, or select images."

Actions:
Scan
Choose PDF
Choose Images

---

# 115. TOOLS CATALOG - COMPLETE

PDF:
- PDF Reader
- Merge PDF
- Split PDF
- Extract Pages
- Delete Pages
- Reorder Pages
- Rotate Pages
- Insert Pages
- Replace Pages
- Duplicate Pages
- Reverse Pages
- Compress PDF
- PDF to JPG
- PDF to PNG
- PDF to WebP
- Images to PDF
- Text to PDF
- HTML to PDF
- Add Text
- Add Image
- Annotate
- Highlight
- Underline
- Strikeout
- Draw
- Shapes
- Sticky Notes
- Whiteout
- Redact
- Sign PDF
- Fill PDF Form
- Flatten PDF
- Watermark PDF
- Page Numbers
- Header/Footer
- Crop PDF
- Resize Pages
- Booklet
- N-up
- Protect PDF
- Unlock PDF with Password
- Metadata
- Optimize PDF
- PDF Properties
- PDF Repair where reliable
- PDF/A where reliable
- PDF to DOCX where reliable
- DOCX to PDF where reliable
- PDF table extraction where reliable
- PDF Text-to-Speech

Images:
- Compress Image
- Exact KB
- Exact MB
- Resize
- Crop
- Rotate
- Flip
- JPG
- PNG
- WebP
- HEIC
- BMP where supported
- TIFF where supported
- Image to PDF
- Batch Compress
- Batch Resize
- Batch Convert
- Batch Rename
- Remove EXIF
- Remove GPS
- Image Editor
- Draw
- Text
- Shapes
- Blur
- Pixelate
- Watermark
- Passport Photo
- ID Photo
- Signature Maker

Scanner:
- Document Scanner
- Receipt Scanner
- ID Scanner
- Passport Scanner
- Business Card Scanner
- Book Scanner
- Photo Scanner
- Multi-page Scanner
- Auto Capture
- Manual Capture
- Perspective Correction
- Auto Crop
- Manual Crop
- Enhancement
- B&W
- Grayscale
- Color
- OCR
- Scan to PDF
- Scan to JPG

OCR:
- Image OCR
- PDF OCR
- Region OCR
- Searchable PDF
- Text Export
- JSON Export
- Copy Text
- OCR Cleanup
- OCR Language Selection

Files:
- Recent
- Favorites
- Folders
- Search
- Sort
- Filter
- Rename
- Move
- Copy
- Delete
- Share
- File Information
- Storage Analyzer
- Duplicate Finder
- ZIP Create
- ZIP Extract
- Archive Browser

Utilities:
- QR Scanner
- Barcode Scanner
- QR Generator
- Signature Maker
- Passport Photo
- Print
- Reminders

AI:
- Summarize PDF
- Ask PDF
- Extract Key Points
- Extract Dates
- Extract Contacts
- Extract Tables
- Translate Text
- Generate Checklist
- Generate Flashcards
- Generate Quiz

---

# 116. PDF READER QUALITY BAR

The reader must not feel like a file preview.

Implement:
- smooth vertical scrolling
- optional horizontal/page mode
- page thumbnails
- current page indicator
- page scrubber
- search with highlighted matches
- zoom controls
- fit width
- fit page
- rotate
- bookmark
- share
- print
- document info
- text selection where engine supports it
- copy
- open external links safely

Large PDF rule:
render only visible pages plus a small bounded prefetch window.

Do not render every page at startup.

---

# 117. PDF PAGE ORGANIZER UX

Use a thumbnail grid/list.

Actions:
- tap to select
- multi-select
- select all
- invert selection where useful
- drag reorder
- rotate selected
- delete selected
- extract selected

Show selection count.

Provide undo before destructive operations where practical.

Never accidentally delete the source document.

---

# 118. PDF EDITOR QUALITY BAR

Editor must support:
- canvas pan
- zoom
- page navigation
- tool palette
- selected-object handles
- snapping where useful
- undo/redo stack
- object deletion
- duplicate
- z-order where supported
- alignment guides where useful

Do not make editing controls tiny.

For tablet:
show tools persistently beside the page.

For phone:
use a bottom toolbar/sheet.

---

# 119. ANNOTATION DATA MODEL

Represent annotations separately from UI state.

Fields may include:
- id
- pageIndex
- type
- bounds
- rotation
- color
- opacity
- strokeWidth
- text
- fontSize
- assetUri
- createdAt
- updatedAt

Undo/redo should operate on commands or immutable state transitions, not screenshots.

---

# 120. REDACTION SAFETY

Real redaction must remove or rasterize the underlying sensitive content in the output.

Validation test:
1. redact visible text
2. save output
3. extract text from output
4. verify redacted text is absent where possible
5. inspect rendered output

A black rectangle over text is NOT sufficient.

---

# 121. PDF PASSWORD UX

Protect:
- choose password
- confirm password
- encryption options only if technically understandable

Unlock:
- ask password
- never store it unless explicitly needed and securely stored
- do not log it

Errors:
- password required
- wrong password
- unsupported encryption

---

# 122. IMAGE ENGINE QUALITY BAR

For every image operation:
- preserve EXIF orientation correctly when needed
- avoid accidental rotation
- preserve alpha when format supports it
- handle huge dimensions safely
- downsample before editing when full resolution is unnecessary
- validate output

Do not decode a 50 MP image at full resolution for a small 400 px thumbnail.

---

# 123. EXACT BYTE COMPRESSION DETAILS

Target values must use a documented unit policy.

Default:
1 KB = 1024 bytes
1 MB = 1024 * 1024 bytes

Expose the policy in developer documentation.

Algorithm:
- determine source format
- normalize orientation
- establish max dimensions
- binary-search quality
- if quality floor is reached, reduce dimensions in bounded steps
- encode
- measure actual bytes
- validate decode
- keep closest output that satisfies the configured tolerance

Never promise mathematically exact bytes for formats/metadata combinations where exact equality cannot be guaranteed.

---

# 124. BATCH JOB UX

Batch screen:
- title
- selected count
- operation
- overall progress
- current file
- per-file state
- cancel all
- retry failed
- open result
- export all

For 100+ files:
use lazy lists.

Never instantiate full-resolution previews for every item.

---

# 125. SCANNER QUALITY BAR

Scanner must handle:
- skew
- perspective
- uneven lighting
- shadows
- low contrast
- dark background
- multi-page

Pipeline:
Camera frame
-> detection
-> capture
-> crop corners
-> perspective transform
-> enhancement
-> preview
-> save
-> optional OCR

Allow manual correction whenever automatic detection is wrong.

Never force users to accept a bad automatic crop.

---

# 126. CAMERA PERFORMANCE

Do not process every camera frame with an expensive model at maximum resolution.

Use:
- bounded preview resolution
- throttled detection
- background processing
- device capability checks

Capture should use an appropriate still-image resolution.

Release camera resources when leaving scanner.

---

# 127. OCR PIPELINE

Image OCR:
image
-> orientation
-> preprocessing
-> OCR
-> post-processing
-> text

Scanned PDF OCR:
PDF
-> page render
-> OCR
-> text layer
-> searchable PDF

Do not OCR every page at startup.

Allow:
- selected pages
- current page
- all pages

Show OCR progress.

---

# 128. OCR ACCURACY UX

Show confidence only if the selected engine provides meaningful confidence values.

Do not invent accuracy percentages.

Allow users to edit extracted text.

For handwritten text:
label support as experimental unless benchmarked.

For tables:
do not flatten table structure into nonsense text without warning.

---

# 129. DOCUMENT LIBRARY INDEXING

Do not automatically crawl the entire device storage.

Default:
index only files Siliph created or folders explicitly selected by the user.

Optional:
user-selected folders can be indexed.

Index metadata first.

OCR indexing must be opt-in where it would consume significant CPU/storage.

---

# 130. DUPLICATE DETECTION

Pipeline:
- user selects folders
- group by size
- group by MIME/type
- hash candidates
- compare SHA-256
- show duplicate groups

Never delete automatically.

Provide:
- select duplicate
- keep oldest/newest
- keep highest resolution
- review manually

The final delete operation must require explicit confirmation.

---

# 131. STORAGE CLEANUP

Safe cleanup categories:
- Siliph temporary files
- failed outputs
- cache
- thumbnails

Never automatically delete user documents.

Show exact location/category before deletion.

---

# 132. LOCAL VAULT

If implemented:
- Android Keystore
- biometric prompt
- device credential fallback
- authenticated encryption
- lock timeout
- screenshot protection where appropriate
- hide sensitive previews

Do not claim perfect protection against rooted/compromised devices.

---

# 133. ONLINE AI ISOLATION

Core app must work without online AI.

Online AI, if added:
- separate service interface
- explicit user action
- network indicator
- privacy explanation
- no automatic document upload
- no background processing
- no API secret embedded in client

For API keys:
use a secure backend/proxy for production services that require a secret.

Never ship a privileged provider secret inside the APK.

---

# 134. AI DOCUMENT RAG

If document Q&A is implemented:

1. extract text
2. preserve page boundaries
3. split into chunks
4. create embeddings only if a suitable local/authorized engine exists
5. retrieve relevant chunks
6. construct prompt/context
7. generate answer
8. attach page references

Never send the entire document unnecessarily.

If an answer cannot be grounded in the document, say so.

---

# 135. AI FAILURE MODES

Handle:
- no text
- scanned image without OCR
- huge document
- unsupported language
- model unavailable
- insufficient device RAM
- network unavailable
- API failure
- rate limit
- context limit

Never crash the core app because AI failed.

---

# 136. DOCUMENT CONVERSION POLICY

Conversion quality varies by document.

Before implementation, benchmark:
- fonts
- tables
- images
- page breaks
- headers/footers
- lists
- Unicode
- forms

For each converter define a support matrix.

Example:
Feature | Supported | Notes
Text | Yes | ...
Tables | Partial | ...
Images | Yes | ...
Forms | No | ...

Display honest limitations.

---

# 137. HTML TO PDF

If implemented locally:
- support local HTML/content
- CSS limitations must be documented
- no arbitrary remote page fetching without user action
- sanitize/limit dangerous content
- handle fonts carefully

If online URL conversion is offered:
- explicit network label
- user action
- privacy warning

---

# 138. PRINTING

Use Android printing APIs where reliable.

Support:
- PDF
- image
- page range
- copies through system dialog

Do not build a custom printer protocol unless necessary.

---

# 139. SHARE/RECEIVE FLOWS

Siliph must support Android intent entry points for appropriate MIME types.

Examples:
- application/pdf
- image/*
- text/plain
- text/html
- application/zip

When receiving a file:
- show source filename
- show detected type
- show safe preview
- offer relevant actions

Example:
Received image
-> Compress
-> Convert
-> OCR
-> Image to PDF

---

# 140. FILE SAFETY

Never trust file extension alone.

Use:
- MIME type
- magic bytes/signature where applicable
- parser validation

Handle renamed/malformed files safely.

Do not execute arbitrary files.

Archive extraction must defend against path traversal.

For ZIP extraction:
- normalize entry paths
- reject ../ traversal
- prevent writing outside destination
- limit suspicious expansion ratios where appropriate

---

# 141. TEMPORARY FILE POLICY

Create a per-job temporary directory.

Example:
cache/jobs/<jobId>/

On completion:
- keep final output
- delete intermediates

On failure/cancel:
- delete incomplete outputs
- preserve useful diagnostics without document contents

On startup:
- clean stale job directories safely

---

# 142. JOB RECOVERY

If the process is killed during a job:
- mark job interrupted
- clean stale temp data when safe
- do not claim the output completed

For resumable operations, resume only when the engine can guarantee correctness.

Do not resume by concatenating corrupt partial output.

---

# 143. BATTERY MANAGEMENT

Avoid:
- continuous polling
- camera processing when scanner is closed
- repeated full-library scans
- unnecessary OCR
- unnecessary thumbnail regeneration

Use event-driven updates.

---

# 144. NETWORK AUDIT

The final APK must be audited for unexpected network traffic.

Verify:
- core processing has no network dependency
- analytics are absent unless explicitly chosen
- AI network calls are isolated
- remote images are not required for core UI

Use Android network/security tooling and packet inspection during QA when appropriate.

---

# 145. ANALYTICS POLICY

Default:
no analytics required.

If analytics is later added:
- no document contents
- no OCR text
- no file paths
- no sensitive filenames
- no document previews
- clear privacy disclosure
- user consent where required

Never make analytics a dependency of core processing.

---

# 146. CRASH REPORTING POLICY

If crash reporting is added:
- strip sensitive metadata
- do not include document contents
- do not include absolute user file paths where avoidable
- allow opt-out where appropriate
- document data handling

For development, local logs are preferred.

---

# 147. LOGGING

Use structured logs.

Good:
PDF_PROCESS_START job=abc operation=compress
PDF_PROCESS_END job=abc duration=1234 outputBytes=12345

Bad:
printing entire document text
printing passwords
printing full URIs containing sensitive paths unnecessarily
printing binary data

Release builds should minimize verbose logs.

---

# 148. PRIVACY COPY

Use accurate wording.

Suggested:
"Siliph is designed to process supported files on your device. Some optional features may require an internet connection. When a feature sends content online, Siliph must clearly tell you before transmission."

Do not claim that every feature is offline if any feature is not.

---

# 149. ACCESSIBILITY QUALITY BAR

Every interactive element needs:
- semantic label
- correct role
- sufficient touch target
- visible focus state where relevant

Test with:
- TalkBack
- large text
- display scaling
- reduced motion
- high contrast/system settings

Avoid placing critical actions only in swipe gestures.

---

# 150. HAPTICS

Use subtle haptics for:
- successful scan capture
- page reorder drop
- favorite toggle
- successful processing
- important destructive confirmation

Do not use haptics for every tap.

Respect system settings.

---

# 151. EMPTY STATES

Every empty screen must answer:
1. What is empty?
2. Why is it empty?
3. What can the user do next?

Examples:

No recent files
"Your processed files will appear here."
[Start a tool]

No favorites
"Save tools and documents you use often."
[Browse tools]

No selected files
"Choose a PDF or image to begin."
[Choose file]

Never display an unexplained blank screen.

---

# 152. ERROR COPY

Errors must be actionable.

Bad:
"Error 0x80004005"

Good:
"This PDF could not be opened. It may be damaged or use an unsupported feature."

Actions:
- Retry
- Choose another file
- Save a copy
- View details

Never expose stack traces to ordinary users.

---

# 153. DESTRUCTIVE ACTIONS

For:
- delete file
- delete pages
- clear history
- clear cache
- delete vault item

Use confirmation only when the action is meaningfully destructive.

Do not show confirmation for every harmless action.

For destructive file deletion, clearly name the file.

---

# 154. UNDO STRATEGY

Implement undo where practical for:
- page deletion
- page reorder
- annotation changes
- image editor operations
- metadata changes before save

Do not implement fake undo that merely reopens the original file if the user has made multiple edits.

---

# 155. SAVE STRATEGY

Default behavior:
- never overwrite original without explicit user choice
- generate safe output filename
- preserve extension
- prevent collisions

Offer:
- Save
- Save As
- Share
- Open

For editing an existing document, make it clear whether the output is replacing or creating a copy.

---

# 156. OUTPUT DIRECTORY STRATEGY

Use an app-controlled default output folder where practical.

Allow user-selected save location through SAF.

Do not silently write to arbitrary shared-storage paths.

If a user chooses a folder, persist the permission when Android permits it.

---

# 157. ONBOARDING

Maximum three screens.

1. Private by design
"Supported processing happens on your device."

2. Everything in one place
"PDF, images, scanning, OCR and file tools."

3. No account required
"Start immediately."

Provide Skip.

Do not require onboarding completion before basic tools can be used.

---

# 158. HOME PERSONALIZATION

Allow:
- favorite tools
- reorder quick actions where useful
- recent tools
- recent files

Do not create a complicated customization system in V1.

---

# 159. SEARCH RANKING

Rank tools using:
1. exact title match
2. alias match
3. keyword match
4. category match
5. recent use
6. favorites

Examples of aliases:
compress pdf:
- reduce pdf
- shrink pdf
- make pdf smaller

image compression:
- reduce photo size
- make picture smaller
- KB photo

scan:
- scan paper
- document scan
- camera PDF

---

# 160. TOOL DISCOVERY

Every tool should have:
- name
- one-line explanation
- icon
- category
- favorite action
- batch capability indicator where relevant
- offline/online indicator where relevant

Avoid unexplained icons.

---

# 161. PREMIUM VISUAL QUALITY BAR

The app should visually compete with polished commercial productivity apps without copying them.

Use:
- strong hierarchy
- consistent spacing
- generous but controlled whitespace
- clear primary action
- beautiful previews
- subtle depth
- high-quality icons
- polished loading states
- useful micro-interactions

Avoid:
- generic template UI
- empty cards everywhere
- random gradients
- inconsistent corner radii
- tiny icons
- excessive shadows
- cluttered toolbars

---

# 162. DESIGN TOKENS

Create centralized tokens:

Spacing:
4, 8, 12, 16, 20, 24, 32, 40

Radius:
8, 12, 16, 20, 24

Typography:
Display
Headline
Title
Body
Label
Caption

Do not create arbitrary one-off values unless required by a component.

---

# 163. COLOR SYSTEM

Light theme first.

Suggested conceptual palette:
- primary Siliph purple
- neutral background
- elevated surface
- primary text
- secondary text
- divider
- success
- warning
- error
- info

Keep actual color values centralized.

Ensure WCAG-appropriate contrast for text and important controls.

---

# 164. ICON SYSTEM

Use Material Symbols or another properly licensed icon source for generic actions.

Create custom Siliph vectors for:
- Compress PDF
- Merge PDF
- Scanner
- OCR
- Exact KB
- Image compression
- Document library
- Privacy

Do not use competitor icons.

---

# 165. GRAPHICS SYSTEM

Create original vector/low-resolution illustrations.

No remote images required for launch.

Assets should be:
- lightweight
- scalable
- accessible
- consistent

For large illustrations, prefer optimized SVG/vector or compressed raster assets.

---

# 166. SPLASH SCREEN

Use Android/Flutter-supported splash configuration.

Keep it short.

Do not perform heavy initialization before first frame.

Show brand only, then load Home.

---

# 167. APP STARTUP GATE

Do not block startup on:
- OCR model loading
- database full scan
- thumbnail generation
- PDF engine initialization
- network

Initialize only what Home requires.

Lazy-load heavy engines.

---

# 168. THUMBNAIL CACHE

Cache thumbnails by:
- stable file identity
- last modified time where available
- size/page index
- rendering options

Invalidate when source changes.

Use bounded cache size.

Never let thumbnail cache consume uncontrolled storage.

---

# 169. IMAGE PREVIEW CACHE

For image tools:
- preview uses downsampled image
- full-resolution output is generated only when saving

Avoid repeated full-resolution transformations while sliders move.

---

# 170. PDF PREVIEW CACHE

For PDF page thumbnails:
- render bounded size
- cache per page
- use LRU behavior
- cancel obsolete thumbnail requests

When user scrolls quickly:
prioritize visible pages.

---

# 171. CONCURRENCY LIMITS

Do not simply spawn one isolate/thread per file.

Use bounded concurrency based on device capability.

Example policy:
- low RAM: 1-2 workers
- normal: small bounded pool
- high-end: benchmarked higher concurrency

Make it configurable internally.

---

# 172. ISOLATES / NATIVE WORK

Dart CPU-heavy work may use isolates when appropriate.

However, native PDF/image/OCR engines should remain native when they provide better memory/performance characteristics.

Do not move work to an isolate merely to hide inefficient algorithms.

Measure first.

---

# 173. PERFORMANCE TARGETS

Targets are engineering goals, not guarantees.

Home first usable frame:
- target fast startup on representative mid-range Android devices

Tool search:
- effectively instant for local catalog

UI interaction:
- no noticeable jank during normal navigation

PDF first-page preview:
- optimize for fast first visible page

Compression:
- progress must be truthful

Large file:
- bounded memory
- no avoidable OOM

Document processing:
- user can cancel

Benchmark every claim on real devices.

---

# 174. JANK INVESTIGATION

When UI is slow:
1. reproduce
2. profile
3. identify expensive frame/build/layout/paint work
4. identify native bridge overhead if relevant
5. fix root cause
6. rerun benchmark

Do not solve every performance issue by adding more loading spinners.

---

# 175. MEMORY TESTING

Use representative devices and files.

Track:
- RSS where available
- Dart heap
- native heap where measurable
- bitmap allocation
- cache size
- temp files

Stress:
- 500-page PDF
- image-heavy PDF
- 100+ image batch
- large camera images

---

# 176. LARGE FILE TESTS

Mandatory scenarios:
- 100 MB PDF
- 250 MB PDF
- 500 MB PDF where device permits
- 1 GB file where device/storage permits
- 50 MP image where device permits
- 100+ image batch

The app must fail gracefully when device resources are insufficient.

---

# 177. STORAGE PRE-FLIGHT

Before processing:
- determine approximate required temporary space when practical
- inspect available app/storage capacity
- reserve only what is necessary

If insufficient:
"Not enough free storage to complete this operation."

Never start a huge job that is guaranteed to fail because storage is obviously insufficient.

---

# 178. OUTPUT VALIDATION TEST MATRIX

For every engine operation test:
- success
- cancellation
- invalid input
- unsupported input
- low storage
- permission denied
- corrupted input
- large input
- Unicode names
- duplicate names
- output collision

---

# 179. FILE NAME EDGE CASES

Test:
- spaces
- Unicode
- Bengali
- Hindi
- emoji filenames where Android permits them
- very long names
- reserved characters
- duplicate names
- no extension
- misleading extension

Generate safe output names.

---

# 180. URI EDGE CASES

Test:
- local file URI
- content URI
- Photo Picker URI
- Google Drive URI if shared by Android as a content URI
- removable storage URI
- persistable URI
- permission revoked URI

Do not assume every URI can be converted to a filesystem path.

Prefer ContentResolver streaming for content URIs.

---

# 181. PERMISSION MATRIX

Camera:
request only when scanner starts.

Photos/files:
use system pickers wherever possible.

Notifications:
request only if required by the actual feature and platform rules.

Storage:
avoid broad permissions.

Biometric:
request only when vault is enabled.

Every permission must have:
- reason
- runtime handling
- denial handling
- settings recovery if appropriate

---

# 182. ANDROID BACK / PREDICTIVE BACK

Test:
- Home back behavior
- tool back
- bottom sheet back
- PDF reader back
- editor back
- unsaved changes

For unsaved edits:
show a clear choice:
Save
Discard
Cancel

Support predictive back behavior where the current Flutter/Android stack allows it.

---

# 183. SCREEN ROTATION

Test rotation during:
- PDF reading
- PDF editing
- scanning
- image editing
- processing
- result screen

Do not lose user selections or job state unnecessarily.

Camera rotation must be handled correctly.

---

# 184. PROCESS DEATH

Android may kill the app.

Persist enough non-sensitive state to restore:
- current tool
- job identifier
- safe metadata

Do not persist passwords or sensitive document contents just for restoration.

---

# 185. NOTIFICATION POLICY

For long-running visible jobs:
- show meaningful progress when Android policy and UX justify it
- allow tap to return to job/result
- completion notification should be useful

Do not send marketing notifications by default.

---

# 186. BACKGROUND WORK

Do not assume a long PDF job can run forever in the background.

Use WorkManager/foreground execution only when justified by current Android rules.

Test Android 16 background/foreground-service behavior.

A background job must be resumable or safely cancellable.

---

# 187. PLAY STORE BUILD

Use:
flutter build appbundle

AAB is the preferred Play Store release artifact.

Also produce a release APK for device QA where useful.

Use release signing.

Enable R8/minification where compatible and verify functionality after shrinking.

Do not publish an untested release build.

---

# 188. FLUTTER RELEASE HARDENING

Before release:
- flutter analyze
- dart format --set-exit-if-changed .
- flutter test
- integration tests
- release build
- inspect APK/AAB size
- check native symbols/mappings
- preserve obfuscation mapping files
- test R8/minified build

Do not expose debug endpoints or logs in release.

---

# 189. CI

Use GitHub Actions or another CI system.

Pipeline:
1. checkout
2. install pinned Flutter version
3. pub get
4. format check
5. analyze
6. unit tests
7. widget tests
8. Android native tests
9. build debug
10. build release/AAB on protected branch
11. artifact upload

Do not store signing keys or API secrets in repository.

---

# 190. DEPENDENCY LOCK

Commit the appropriate dependency lockfile for the chosen workflow.

Review dependency updates before upgrading.

Do not run blind mass upgrades shortly before release.

For native Android dependencies, use compatible Gradle/Kotlin/AGP versions required by the selected Flutter stable toolchain.

---

# 191. LICENSE INVENTORY

Create docs/licenses.md containing:
- dependency
- version
- license
- source
- modifications
- attribution requirements

Also preserve required LICENSE/NOTICE files inside the app/repository where required.

---

# 192. PRIMARY REPOSITORY MIGRATION PLAN

For Karna14314/Pdf_Tools:

DO NOT:
- mechanically translate Kotlin UI into Dart
- copy Compose screens into Flutter
- assume every dependency can be used in Flutter

DO:
1. inspect PDF processing code
2. inspect image processing code
3. inspect OCR integration
4. inspect CameraX/scanner implementation
5. identify stable reusable native logic
6. keep or adapt it in Kotlin when appropriate
7. expose it through Pigeon/native APIs
8. replace Compose UI with Flutter
9. create Siliph design system
10. run license audit

The repository is a processing reference and possible native engine source, not a Flutter UI template.

---

# 193. SOURCE MODIFICATION RECORD

For every reused module create:

Source:
Original repository:
Original commit/version:
License:
Files copied/adapted:
Changes made:
Reason:
Siliph destination:

Never lose provenance.

---

# 194. FEATURE FLAGS

Use feature flags only for:
- experimental AI
- unstable conversion engines
- device-specific fallbacks
- staged rollout

Do not hide broken P0 functionality behind a feature flag at release.

---

# 195. DEVICE CAPABILITY DETECTION

Before enabling advanced features, detect:
- Android API
- available storage
- memory pressure where possible
- camera capability
- biometric capability
- OCR model availability
- required codec support

If unsupported:
show an honest explanation and alternative.

---

# 196. OFFLINE TEST PROCEDURE

Test with:
- airplane mode
- Wi-Fi disabled
- mobile data disabled
- DNS/network blocked where possible

Verify P0:
- open PDF
- merge
- split
- compress
- image compression
- scanner
- OCR with installed local engine/model
- image conversion
- ZIP
- save
- share to local apps

If a supposed offline feature fails, fix the dependency or relabel it.

---

# 197. NETWORK-DEPENDENT FEATURE LABELING

Every network-dependent feature must display:
- Requires internet

Before sending a document:
"This feature sends the selected document/content to an online service."

Buttons:
Continue
Cancel

Do not pre-upload.

---

# 198. NO ACCOUNT ARCHITECTURE

There is no user account system in V1.

Do not add:
- email login
- phone login
- OTP
- mandatory cloud account

unless the product requirements are explicitly changed later.

Local preferences and files must work without identity.

---

# 199. MONETIZATION COMPATIBILITY

The architecture should allow future monetization without corrupting core local functionality.

Possible future options:
- one-time Pro unlock
- optional subscription for advanced online AI/cloud features
- ads only if deliberately chosen later

Do not introduce advertising SDKs merely for development.

Never use ads in a way that blocks core file operations without a clear product decision.

---

# 200. NO CLOUD STORAGE REQUIREMENT

Do not build cloud storage into V1.

The user's device is the source of truth.

If cloud backup is added later, it must be a separate opt-in product feature.

---

# 201. LOCAL DATA EXPORT

Allow users to manage local Siliph metadata.

Optional:
- export settings
- export tool presets
- export document index metadata

Do not export sensitive content unless explicitly requested.

---

# 202. RESET APP DATA UX

Settings:
Clear cache
Clear recent history
Reset preferences

If Android app-data reset is outside Siliph control, explain that system settings can clear all app data.

Do not delete user-selected external documents when clearing cache/history.

---

# 203. DOCUMENT PREVIEW SECURITY

For sensitive documents:
- do not expose full previews in notifications
- do not put sensitive text in analytics
- consider Android screenshot protection for vault screens
- clear clipboard after sensitive copy only when the product behavior and Android policy make it appropriate

Do not overclaim security.

---

# 204. CLIPBOARD

When copying OCR/PDF text:
- use Android clipboard correctly
- do not log clipboard contents
- consider a user-visible confirmation for sensitive operations

Do not automatically copy sensitive document text.

---

# 205. SEARCHABLE PDF QUALITY

When generating searchable PDF:
- preserve original page appearance
- add OCR text layer with correct positioning when supported
- preserve page dimensions
- avoid visibly changing the document unless requested
- validate that search can find OCR text

---

# 206. PDF FONT HANDLING

For generated PDFs:
- use licensed/appropriate fonts
- embed fonts when required for reliable rendering
- support Unicode text
- test Bengali/Hindi/English output

Do not bundle proprietary fonts without permission.

---

# 207. INTERNATIONALIZATION

Use Flutter localization/ARB files.

Initial:
- English
- Hindi
- Bengali

Prepare for:
- pluralization
- text expansion
- RTL future support
- locale-specific date/number formatting

Do not concatenate translated fragments into grammatically broken sentences.

---

# 208. DATE/TIME

Use locale-aware formatting.

Store timestamps in a stable representation.

Display in the user's local timezone.

Do not hard-code date formats.

---

# 209. ACCESSIBILITY LABEL EXAMPLES

Bad:
"icon"

Good:
"Compress PDF"

Bad:
"button"

Good:
"Start PDF compression"

For decorative icons:
exclude them from semantics when appropriate.

---

# 210. QA TEST CASE FORMAT

Each test case should include:
ID
Feature
Precondition
Steps
Expected result
Actual result
Device/API
Status
Notes

Example:
PDF-COMP-001
Compress PDF
Valid 20 MB PDF
1. Select PDF
2. Choose medium
3. Process
Expected: output opens and is smaller when compression is effective.

---

# 211. REGRESSION POLICY

Every bug fixed should create a regression test where practical.

Bug:
"PDF with Bengali filename fails to save."

Add test:
Unicode filename save/export.

Bug:
"Cancel leaves partial file."

Add test:
Cancellation cleanup.

Bug:
"Scanner rotates landscape page incorrectly."

Add test:
Orientation handling.

---

# 212. USER FEEDBACK INTERPRETATION

When the user says:
"Make it better"

Do not make random changes.

Inspect:
- hierarchy
- spacing
- consistency
- performance
- accessibility
- information density
- primary action visibility

Then make measurable improvements.

When the user says:
"This looks empty"

Do not merely add decorative cards.

Add useful content:
- popular tools
- categories
- recent files
- suggested actions
- contextual actions

---

# 213. AI AGENT RESPONSE FORMAT

After each implementation step:

STATUS
PASS / PARTIAL / BLOCKED

IMPLEMENTED
- ...

FILES CHANGED
- ...

TESTS RUN
- ...

RESULT
- ...

KNOWN LIMITATIONS
- ...

LICENSE IMPACT
- ...

NEXT STEP
- ...

Never claim a test passed if it was not run.

---

# 214. AI AGENT STOP CONDITIONS

Stop and ask for clarification only when:
- a product requirement is genuinely ambiguous and cannot be safely inferred
- a license prohibits the intended use
- a required external credential is missing
- an irreversible destructive action is requested
- a feature cannot be implemented safely/reliably without changing scope

Otherwise continue independently through the current phase.

Do not repeatedly ask permission for ordinary implementation decisions.

---

# 215. AI AGENT NO-HALLUCINATION RULE

Never claim:
- a package supports a feature without checking
- a repository contains a feature without inspecting it
- a conversion is lossless without testing
- OCR is perfect
- a file is secure without validation
- a Play Store policy is satisfied without checking current requirements

If uncertain:
inspect source/docs, test, or mark the limitation.

---

# 216. CURRENT OFFICIAL DOCUMENTATION CHECK

Before final release, verify current official documentation for:
- Flutter stable release
- Flutter Android deployment
- Flutter Android integration/Pigeon
- Android 16/API 36 behavior changes
- Play target API requirements
- Android storage/Photo Picker
- CameraX
- ML Kit
- Android background execution
- notification permissions
- Play Data Safety

Do not rely on this prompt as a permanent substitute for current platform documentation.

---

# 217. FINAL V1 FEATURE GATE

P0 must be complete:

APP:
- no sign-in
- polished light theme
- Home
- Tools
- Search
- Recent
- Settings
- file picker
- save/share

PDF:
- reader
- search
- merge
- split
- extract
- delete
- reorder
- rotate
- insert
- replace
- compress
- image conversion
- image to PDF
- annotation
- signature
- watermark
- metadata
- password protection
- valid-password unlock
- forms where supported
- flatten
- real redaction

IMAGE:
- compress
- exact KB/MB
- resize
- crop
- rotate
- flip
- conversion
- image to PDF
- metadata removal
- batch

SCANNER:
- document
- multi-page
- crop
- perspective correction
- enhancement
- PDF
- JPG

OCR:
- image
- scanned PDF
- searchable PDF
- text export
- supported initial languages

FILES:
- recent
- favorites
- folders
- search
- rename
- move/copy
- delete
- share
- ZIP

QUALITY:
- cancellation
- progress
- output validation
- error handling
- large-file safety
- offline core operation
- accessibility
- Android 16 compatibility
- tests
- license audit

---

# 218. P1/P2 RELEASE ROADMAP

P1:
- advanced PDF tools
- image editor
- passport/ID photo
- QR/barcode
- duplicate finder
- storage analyzer
- smart folders
- reminders
- print
- text-to-speech

P2:
- table extraction
- Office conversion
- PDF/A
- booklet/N-up
- local vault
- advanced OCR languages
- advanced document search

P3:
- on-device AI
- optional online AI
- semantic search
- document Q&A
- AI translation
- flashcards/quiz

P3 features must never destabilize P0.

---

# 219. FINAL PERFORMANCE GATE

Release candidate must pass:
- startup benchmark
- tool search benchmark
- PDF first render benchmark
- merge benchmark
- compression benchmark
- image compression benchmark
- scanner processing benchmark
- OCR benchmark
- memory stress
- 100+ image batch
- large PDF test

Record results in docs/performance.md.

Do not publish fabricated benchmark numbers.

---

# 220. FINAL SECURITY GATE

Before release:
- no embedded production API secrets
- no unnecessary permissions
- no hidden upload
- no document text in analytics
- no passwords in logs
- no debug endpoints
- no test credentials
- no unsafe archive extraction
- no path traversal
- no insecure custom cryptography
- temporary files cleaned
- license inventory complete

---

# 221. FINAL PLAY STORE GATE

Prepare:
- signed AAB
- versionCode/versionName
- adaptive icon
- app icon
- screenshots
- feature graphic
- short description
- full description
- privacy policy
- Data Safety answers
- content rating
- app category
- support/contact page

Verify all claims.

Do not say:
- zero bugs
- 100% accurate OCR
- perfect conversion
- 100% offline if optional AI/conversion is online
- guaranteed government compliance
- guaranteed secure deletion

---

# 222. FINAL CLEAN BUILD TEST

Delete build artifacts and caches where appropriate.

Clone the repository into a clean environment.

Install the pinned Flutter SDK/toolchain.

Run:
- dependency install
- analyzer
- formatter check
- unit tests
- widget tests
- integration tests
- Android native tests
- release AAB build

Install the release build on a physical Android device.

Test core flows manually.

Only then call the release candidate complete.

---

# 223. FINAL AI CODING AGENT COMMAND

START NOW.

Step 1: audit the repository and current environment.
Step 2: verify the current stable Flutter/Android toolchain.
Step 3: inspect Karna14314/Pdf_Tools and its licenses.
Step 4: produce the feature/dependency/license matrix.
Step 5: create the Flutter project architecture.
Step 6: implement the design system and Home before heavy engines.
Step 7: establish the typed native bridge.
Step 8: migrate/adapt processing engines only after understanding them.
Step 9: implement P0 features phase-by-phase.
Step 10: compile and test after every phase.
Step 11: benchmark large files.
Step 12: add regression tests for every important bug.
Step 13: implement P1/P2 features without destabilizing P0.
Step 14: evaluate AI only after the local core is reliable.
Step 15: complete security/privacy/license audits.
Step 16: build and test the release AAB.
Step 17: perform final UX review.
Step 18: report exact completion status.

Never stop at a visually impressive prototype.

The goal is a functioning product.

---

# 224. FINAL PRODUCT STANDARD

Siliph must be:

FAST
PRIVATE
LOCAL-FIRST
BEAUTIFUL
ACCESSIBLE
RELIABLE
FEATURE-RICH
EASY TO USE
ADAPTIVE
TESTED
LICENSE-COMPLIANT
PLAY-READY

The user should be able to install Siliph, open it, choose a file or scan a document, perform a useful operation, save the result, and share it without creating an account.

When the user provides feedback, treat it as a product-quality signal. Find the root cause, improve the reusable architecture or design system, add regression coverage where practical, rebuild, and verify adjacent workflows.

Never stop at "looks good".

Build it.
Test it.
Measure it.
Review it.
Fix it.
Improve it.
Then ship it.
