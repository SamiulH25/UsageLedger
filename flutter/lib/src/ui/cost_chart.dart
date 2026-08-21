import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Daily tracked spend.
///
/// Columns are deliberately colourless — spend is not a health reading, so it
/// stays out of the thermal ramp. Only today is picked out, and a dashed mean
/// line gives every column something to be measured against.
class CostChart extends StatelessWidget {
  final List<({String day, double costUsd})> series;

  const CostChart({super.key, required this.series});

  @override
  Widget build(BuildContext context) {
    final data = series.length > 14
        ? series.sublist(series.length - 14)
        : series;
    if (data.length < 2) return const SizedBox.shrink();

    final total = data.fold<double>(0, (sum, point) => sum + point.costUsd);
    final peak = data.reduce((a, b) => a.costUsd >= b.costUsd ? a : b);
    final mean = total / data.length;

    return Semantics(
      container: true,
      label:
          'Tracked spend for the last ${data.length} days. '
          'Total ${fmtCost(total)}. Daily average ${fmtCost(mean)}. '
          'Peak ${fmtCost(peak.costUsd)} on ${peak.day}.',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('DAILY', style: AppText.tag(size: 9.5)),
                const Spacer(),
                Text(
                  'avg ${fmtCost(mean)}',
                  style: AppText.data(size: 10, color: AppColors.haze),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 92,
              child: CustomPaint(
                size: const Size(double.infinity, 92),
                painter: _ColumnsPainter(
                  values: [for (final point in data) point.costUsd],
                  mean: mean,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  _short(data.first.day),
                  style: AppText.data(size: 9.5, color: AppColors.haze),
                ),
                const Spacer(),
                Text(
                  _short(data.last.day),
                  style: AppText.data(size: 9.5, color: AppColors.haze),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _short(String isoDay) =>
      isoDay.length >= 10 ? isoDay.substring(5).replaceAll('-', '.') : isoDay;
}

class _ColumnsPainter extends CustomPainter {
  final List<double> values;
  final double mean;

  _ColumnsPainter({required this.values, required this.mean});

  @override
  void paint(Canvas canvas, Size size) {
    final maxV = values.reduce(math.max);
    final denom = maxV <= 0 ? 1.0 : maxV;
    final slot = size.width / values.length;
    final barW = math.min(slot - 4, 22.0).clamp(2.0, 22.0);

    // Baseline.
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 1, size.width, 1),
      Paint()..color = AppColors.rule,
    );

    for (var i = 0; i < values.length; i++) {
      final h = ((values[i] / denom) * (size.height - 6)).clamp(
        2.0,
        size.height - 4,
      );
      final x = slot * i + (slot - barW) / 2;
      final latest = i == values.length - 1;
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(x, size.height - 1 - h, barW, h),
          topLeft: const Radius.circular(1),
          topRight: const Radius.circular(1),
        ),
        Paint()..color = latest ? AppColors.beam : AppColors.rule,
      );
    }

    // Mean line — dashed so it never reads as another column.
    if (mean > 0 && maxV > 0) {
      final y = size.height - 1 - (mean / denom) * (size.height - 6);
      final paint = Paint()
        ..color = AppColors.haze.withValues(alpha: .55)
        ..strokeWidth = 1;
      for (var x = 0.0; x < size.width; x += 6) {
        canvas.drawLine(Offset(x, y), Offset(x + 3, y), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_ColumnsPainter old) =>
      old.values != values || old.mean != mean;
}

/// Minimal polyline sparkline for per-account trend rows.
class Sparkline extends StatelessWidget {
  final List<double> values;
  final Color color;
  final double strokeWidth;

  const Sparkline({
    super.key,
    required this.values,
    this.color = AppColors.coldLit,
    this.strokeWidth = 1.6,
  });

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    final min = values.reduce(math.min);
    final max = values.reduce(math.max);
    return Semantics(
      container: true,
      label:
          'Spend trend. Lowest ${fmtCost(min)}, highest ${fmtCost(max)}, '
          'latest ${fmtCost(values.last)}.',
      child: ExcludeSemantics(
        child: CustomPaint(
          size: const Size(double.infinity, 40),
          painter: _SparklinePainter(
            values: values,
            color: color,
            strokeWidth: strokeWidth,
          ),
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final double strokeWidth;

  _SparklinePainter({
    required this.values,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final maxV = values.reduce(math.max);
    final minV = values.reduce(math.min);
    final span = (maxV - minV) <= 0 ? 1.0 : maxV - minV;

    double yAt(int i) =>
        size.height - 3 - ((values[i] - minV) / span) * (size.height - 6);
    double xAt(int i) => i / (values.length - 1) * (size.width - 4) + 2;

    final path = Path()..moveTo(xAt(0), yAt(0));
    for (var i = 1; i < values.length; i++) {
      path.lineTo(xAt(i), yAt(i));
    }

    // Faint fill under the trace so a flat line still reads as a chart.
    final fill = Path.from(path)
      ..lineTo(xAt(values.length - 1), size.height)
      ..lineTo(xAt(0), size.height)
      ..close();
    canvas.drawPath(fill, Paint()..color = color.withValues(alpha: .1));

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    canvas.drawCircle(
      Offset(xAt(values.length - 1), yAt(values.length - 1)),
      2.6,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.values != values || old.color != color;
}
