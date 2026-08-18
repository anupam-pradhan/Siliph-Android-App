/// Document detection service.
///
/// Analyses camera frames (as [Uint8List] JPEG bytes) to detect
/// rectangular document boundaries.
library;

import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// Detected document quadrilateral as 8 normalised values
/// (TLx, TLy, TRx, TRy, BRx, BRy, BLx, BLy) in 0..1 range.
class DetectedDocument {
  const DetectedDocument({
    required this.corners,
    required this.confidence,
  });

  final List<double> corners;
  final double confidence;

  double get areaFraction {
    final pts = [
      Offset(corners[0], corners[1]),
      Offset(corners[2], corners[3]),
      Offset(corners[4], corners[5]),
      Offset(corners[6], corners[7]),
    ];
    double area = 0;
    for (var i = 0; i < 4; i++) {
      final j = (i + 1) % 4;
      area += pts[i].dx * pts[j].dy;
      area -= pts[j].dx * pts[i].dy;
    }
    return (area.abs() / 2).clamp(0.0, 1.0);
  }

  bool get isLikelyDocument => confidence > 0.3 && areaFraction > 0.08;
}

/// Processes a JPEG frame and returns detected document corners.
Future<DetectedDocument?> detectDocument(Uint8List jpegBytes) async {
  try {
    final codec = await ui.instantiateImageCodec(jpegBytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final width = image.width;
    final height = image.height;

    final scale = (320 / max(width, height)).clamp(0.0, 1.0);
    final sw = (width * scale).round();
    final sh = (height * scale).round();

    final byteData = await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    if (byteData == null) {
      image.dispose();
      return null;
    }

    final rgba = byteData.buffer.asUint8List();
    final gray = Uint8List(sw * sh);
    for (var y = 0; y < sh; y++) {
      for (var x = 0; x < sw; x++) {
        final srcX = (x / scale).round().clamp(0, width - 1);
        final srcY = (y / scale).round().clamp(0, height - 1);
        final idx = (srcY * width + srcX) * 4;
        gray[y * sw + x] =
            ((rgba[idx] * 0.299 + rgba[idx + 1] * 0.587 + rgba[idx + 2] * 0.114)
                .round());
      }
    }
    image.dispose();

    final edgeMag = Float32List(sw * sh);
    for (var y = 1; y < sh - 1; y++) {
      for (var x = 1; x < sw - 1; x++) {
        final idx = y * sw + x;
        final gx = gray[idx + 1].toDouble() - gray[idx - 1].toDouble();
        final gy = gray[(y + 1) * sw + x].toDouble() -
            gray[(y - 1) * sw + x].toDouble();
        edgeMag[idx] = sqrt(gx * gx + gy * gy);
      }
    }

    double threshold = 0;
    final sorted = Float32List.fromList(edgeMag)..sort();
    final topCount = (sw * sh * 0.15).round();
    if (topCount > 0 && topCount < sorted.length) {
      threshold = sorted[sorted.length - topCount];
    }
    if (threshold < 20) threshold = 20;

    final edgePoints = <Offset>[];
    for (var y = 2; y < sh - 2; y += 2) {
      for (var x = 2; x < sw - 2; x += 2) {
        if (edgeMag[y * sw + x] >= threshold) {
          edgePoints.add(Offset(x.toDouble(), y.toDouble()));
        }
      }
    }

    if (edgePoints.length < 20) return null;

    final quad = _findLargestQuad(edgePoints, sw, sh);
    if (quad == null) return null;

    final normalised = <double>[];
    for (var i = 0; i < 4; i++) {
      normalised.add((quad[i].dx / sw).clamp(0.0, 1.0));
      normalised.add((quad[i].dy / sh).clamp(0.0, 1.0));
    }

    final confidence = _edgeDensityAlongQuad(quad, edgePoints);

    return DetectedDocument(corners: normalised, confidence: confidence);
  } catch (_) {
    return null;
  }
}

List<Offset>? _findLargestQuad(List<Offset> points, int w, int h) {
  if (points.length < 10) return null;
  final hull = _convexHull(points);
  if (hull.length < 4) return null;
  var simplified = _douglasPeucker(hull, 2.0);
  if (simplified.length < 4 && hull.length >= 4) {
    simplified = _douglasPeucker(hull, 1.0);
  }
  if (simplified.length < 4) return null;
  if (simplified.length > 4) {
    simplified = _douglasPeucker(simplified, 3.0);
  }
  return simplified.length == 4 ? simplified : null;
}

List<Offset> _convexHull(List<Offset> points) {
  if (points.length <= 3) return List.of(points);
  final sampled = points.length > 200
      ? List.generate(200, (i) => points[i * points.length ~/ 200])
      : points;
  sampled.sort((a, b) {
    final cmp = a.dx.compareTo(b.dx);
    return cmp != 0 ? cmp : a.dy.compareTo(b.dy);
  });
  final hull = <Offset>[];
  for (final p in sampled) {
    while (hull.length >= 2 &&
        _cross(hull[hull.length - 2], hull[hull.length - 1], p) <= 0) {
      hull.removeLast();
    }
    hull.add(p);
  }
  final lowerLen = hull.length + 1;
  for (var i = sampled.length - 2; i >= 0; i--) {
    final p = sampled[i];
    while (hull.length >= lowerLen &&
        _cross(hull[hull.length - 2], hull[hull.length - 1], p) <= 0) {
      hull.removeLast();
    }
    hull.add(p);
  }
  hull.removeLast();
  return hull;
}

double _cross(Offset o, Offset a, Offset b) {
  return (a.dx - o.dx) * (b.dy - o.dy) - (a.dy - o.dy) * (b.dx - o.dx);
}

List<Offset> _douglasPeucker(List<Offset> points, double epsilon) {
  if (points.length <= 2) return List.of(points);
  var maxDist = 0.0;
  var maxIdx = 0;
  final first = points.first;
  final last = points.last;
  final lineLen = (last - first).distance;
  if (lineLen < 0.001) return [first, last];
  for (var i = 1; i < points.length - 1; i++) {
    final d = _perpendicularDist(points[i], first, last, lineLen);
    if (d > maxDist) {
      maxDist = d;
      maxIdx = i;
    }
  }
  if (maxDist > epsilon) {
    final left = _douglasPeucker(points.sublist(0, maxIdx + 1), epsilon);
    final right = _douglasPeucker(points.sublist(maxIdx), epsilon);
    return [...left.sublist(0, left.length - 1), ...right];
  }
  return [first, last];
}

double _perpendicularDist(Offset p, Offset a, Offset b, double lineLen) {
  final area =
      ((b.dx - a.dx) * (a.dy - p.dy) - (a.dx - p.dx) * (b.dy - a.dy)).abs();
  return area / lineLen;
}

double _edgeDensityAlongQuad(List<Offset> quad, List<Offset> edgePoints) {
  var total = 0;
  var matched = 0;
  for (var side = 0; side < 4; side++) {
    final a = quad[side];
    final b = quad[(side + 1) % 4];
    final segLen = (b - a).distance;
    final steps = (segLen / 2).round().clamp(3, 50);
    for (var s = 0; s <= steps; s++) {
      final t = s / steps;
      final px = a.dx + (b.dx - a.dx) * t;
      final py = a.dy + (b.dy - a.dy) * t;
      total++;
      for (final ep in edgePoints) {
        if ((ep - Offset(px, py)).distance < 5) {
          matched++;
          break;
        }
      }
    }
  }
  return total > 0 ? matched / total : 0;
}

/// Smooths corner positions to reduce jitter.
List<double>? smoothCorners(
  List<double>? prev,
  List<double>? curr, {
  double factor = 0.4,
}) {
  if (prev == null || curr == null || prev.length != 8 || curr.length != 8) {
    return curr;
  }
  return List.generate(8, (i) => prev[i] + (curr[i] - prev[i]) * factor);
}
