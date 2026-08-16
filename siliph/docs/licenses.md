# Licenses

Status reflects the current build phase. Update whenever a dependency is
added or removed (master prompt section 104).

## Runtime dependencies

| Dependency | Version | License | Purpose |
|---|---|---|---|
| flutter_riverpod | 3.x | MIT | State management (section 111 decision) |
| go_router | 17.x | BSD-3-Clause | Declarative routing (section 112) |
| com.tom-roush:pdfbox-android | 2.0.27.0 | Apache-2.0 | Native PDF engine (render, stamp, annotate, redact, OCR rebuild). Vendored in `android/local-repo` because the artifact left Maven Central |
| com.google.mlkit:text-recognition | 16.0.1 | Apache-2.0 | Bundled on-device OCR (Latin/English) |
| com.google.mlkit:text-recognition-devanagari | 16.0.1 | Apache-2.0 | Bundled on-device OCR (Hindi/Devanagari) |
| com.google.mlkit:barcode-scanning | 17.3.0 | Apache-2.0 | Bundled on-device QR/barcode decode (qr-scan) |
| androidx.core:core-ktx | 1.13.1 | Apache-2.0 | FileProvider for camera capture hand-off |

## Reused source code

| Source | License | Record |
|---|---|---|
| Karna14314/Pdf_Tools @ bb4125bf (PdfMerger.kt, MemoryGuard.kt) | Apache-2.0 | docs/reuse-records.md |

Apache-2.0 obligations: the upstream LICENSE is preserved in the reference
clone used during development; attribution is recorded in
docs/reuse-records.md. If Siliph ships with the adapted Kotlin code (it
does), include the Apache-2.0 license text in the app's license screen when
one is added (planned with the About phase).

## Dev-only dependencies (not shipped)

pigeon (BSD-3-Clause), flutter_test, analyzer toolchain.
