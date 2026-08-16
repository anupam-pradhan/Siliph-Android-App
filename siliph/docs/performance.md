# Siliph Performance & Benchmark Gates

Status: Validated on Flutter 3.44+ / Android 16 (API 36) baseline.

This document records the performance standards, memory boundaries, and benchmark gates required by Master Build Prompt Section 219.

---

## 1. Core Performance Gates & Benchmarks

| Benchmark Area | Target Threshold | Implementation & Architecture Standard |
|---|---|---|
| **App Startup** | < 800ms warm / < 1.5s cold | Lazy initialization of native modules; no heavy computation on UI thread. |
| **Tool Search** | < 16ms (instant 60fps) | In-memory trie / fuzzy keyword index in Dart isolates; no blocking I/O. |
| **PDF First Page Render** | < 250ms (typical 150 DPI) | Native PDFBox page rasterization with thread-safe cached bitmap rendering. |
| **PDF Merge (10+ docs)** | Streaming progress per doc | Memory-managed temp file usage (`MemoryUsageSetting.setupTempFileOnly()`). |
| **PDF Compression** | Predictable quality presets | Multi-tier bitmap resampling and stream compression with memory guards. |
| **Exact Image Compression**| Bounded binary search (< 10 iters) | Dynamic JPEG quality and dimension scaling with binary search convergence. |
| **Scanner Capture & Warp** | < 400ms per page | Perspective transformation and contrast enhancement on native executor. |
| **On-Device OCR** | < 600ms per standard page | Bundled ML Kit Text Recognition running offline on background worker thread. |
| **Batch Processing** | 100+ items without OOM | Sequential processing queue with per-item progress emission and cancellation. |
| **Large PDF Resilience** | Safe on 500+ page docs | Never load entire document tree into Java/Dart heap at once. |

---

## 2. Memory Safety Architecture

1. **`MemoryGuard` Pre-Flight Checks**:
   - Before executing memory-intensive operations (merging large files, rasterizing high-res PDFs, OCR batches), `MemoryGuard.assertSufficientMemory()` verifies heap headroom.

2. **Temporary File Buffering**:
   - `PDDocument.load` and scratch operations enforce `MemoryUsageSetting.setupTempFileOnly()`.
   - File streams are closed and intermediate buffers are recycled immediately in `finally` blocks.

3. **Background Worker Threads**:
   - Heavy tasks run on dedicated single-thread background executors (`siliph-pdf-worker`, `siliph-ocr-worker`, `siliph-img-worker`, `siliph-file-worker`).
   - Platform channel responses to Dart remain synchronous while work executes asynchronously with typed event streams.

4. **Honest Progress and Cancellation**:
   - Long-running operations support cooperative cancellation tokens (`AtomicBoolean`) checked between page/file iterations.
   - Operations never silently overwrite source files; outputs are generated safely through the Android Storage Access Framework (SAF).
