/// Pure planning helpers for PDF page operations (section 60).
///
/// No Flutter imports: everything here is unit-testable and reusable by the
/// split / extract / delete / reorder / reverse workflows.
library;

/// A one-based inclusive run of pages.
class PageRange {
  const PageRange(this.first, this.last);

  /// First page, one-based inclusive.
  final int first;

  /// Last page, one-based inclusive. >= [first].
  final int last;

  int get count => last - first + 1;

  /// Zero-based page indices for the rearrange engine call.
  List<int> toZeroBasedOrder() => [for (var p = first; p <= last; p++) p - 1];

  @override
  bool operator ==(Object other) =>
      other is PageRange && other.first == first && other.last == last;

  @override
  int get hashCode => Object.hash(first, last);

  @override
  String toString() => first == last ? '$first' : '$first-$last';
}

/// Contiguous ranges for "split every [everyN] pages".
///
/// Returns an empty list when [pageCount] <= 0 or [everyN] <= 0.
List<PageRange> splitPlan(int pageCount, int everyN) {
  if (pageCount <= 0 || everyN <= 0) return const [];
  final ranges = <PageRange>[];
  for (var start = 1; start <= pageCount; start += everyN) {
    final end = (start + everyN - 1).clamp(start, pageCount);
    ranges.add(PageRange(start, end));
  }
  return ranges;
}

/// Clamps a user-typed [first]..[last] against [pageCount].
///
/// Returns null when no valid page remains (empty document, or the range is
/// fully outside).
PageRange? clampRange(int pageCount, int first, int last) {
  if (pageCount <= 0) return null;
  final f = first.clamp(1, pageCount);
  final l = last.clamp(f, pageCount);
  return PageRange(f, l);
}

/// Zero-based order with pages at one-based [deletePages] removed.
///
/// Returns null when nothing would remain.
List<int>? orderWithout(int pageCount, Set<int> deletePages) {
  final order = <int>[];
  for (var p = 0; p < pageCount; p++) {
    if (!deletePages.contains(p + 1)) order.add(p);
  }
  return order.isEmpty ? null : order;
}

/// Default save-as name for one part of a source file.
///
/// `Report.pdf` + part 2 of 5 -> `Report-part-2-of-5.pdf`. Single-part
/// operations keep a simple `-output` suffix instead.
String partName(String sourceName, {required int part, required int of}) {
  final base = stripPdfExtension(sourceName);
  if (of <= 1) return '$base-output.pdf';
  return '$base-part-$part-of-$of.pdf';
}

String stripPdfExtension(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.pdf')) return name.substring(0, name.length - 4);
  return name;
}
