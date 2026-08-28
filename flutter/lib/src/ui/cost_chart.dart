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
}

String _short(String isoDay) =>
    isoDay.length >= 10 ? isoDay.substring(5).replaceAll('-', '.') : isoDay;

class TokenChart extends StatelessWidget {
  final List<({String day, int inputTokens, int outputTokens, int requests})>
  series;

  const TokenChart({super.key, required this.series});

  @override
  Widget build(BuildContext context) {
    final data = series.length > 14
        ? series.sublist(series.length - 14)
        : series;
    if (data.isEmpty ||
        data.every((p) => p.inputTokens + p.outputTokens == 0)) {
      return const SizedBox.shrink();
    }
    final totals = [for (final p in data) p.inputTokens + p.outputTokens];
    final peak = totals.reduce((a, b) => a > b ? a : b);
    final total = totals.fold<int>(0, (a, b) => a + b);
    return Semantics(
      container: true,
      label:
          'Daily tokens for the last ${data.length} days. '
          'Total ${fmtTokens(total)}. Peak ${fmtTokens(peak)}.',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('TOKENS', style: AppText.tag(size: 9.5)),
                const Spacer(),
                Text(
                  'peak ${fmtTokens(peak)}',
                  style: AppText.data(size: 10, color: AppColors.haze),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 92,
              child: CustomPaint(
                size: const Size(double.infinity, 92),
                painter: _TokenColumnsPainter(
                  inputTokens: [for (final p in data) p.inputTokens],
                  outputTokens: [for (final p in data) p.outputTokens],
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
}

class CostPer1kSparkline extends StatelessWidget {
  final List<({String day, double costPer1k})> series;

  const CostPer1kSparkline({super.key, required this.series});

  @override
  Widget build(BuildContext context) {
    final data = series.length > 14
        ? series.sublist(series.length - 14)
        : series;
    final values = [for (final p in data) p.costPer1k];
    if (values.isEmpty || values.every((v) => v == 0)) {
      return const SizedBox.shrink();
    }
    final avg = values.fold<double>(0, (a, b) => a + b) / values.length;
    final last7 = values.length >= 7
        ? values.sublist(values.length - 7)
        : values;
    final prev7 = values.length >= 14
        ? values.sublist(values.length - 14, values.length - 7)
        : const <double>[];
    final lastAvg = last7.fold<double>(0, (a, b) => a + b) / last7.length;
    final prevAvg = prev7.isEmpty
        ? 0.0
        : prev7.fold<double>(0, (a, b) => a + b) / prev7.length;
    final delta = prevAvg > 0 ? ((lastAvg - prevAvg) / prevAvg * 100) : 0.0;
    final deltaLabel = prevAvg == 0
        ? ''
        : delta >= 0
        ? ' · ${delta.toStringAsFixed(0)}% vs prev 7d'
        : ' · ${delta.toStringAsFixed(0)}% vs prev 7d';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('COST / 1K', style: AppText.tag(size: 9.5)),
            const Spacer(),
            Text(
              'avg ${fmtCost(avg)}/1k$deltaLabel',
              style: AppText.data(size: 10, color: AppColors.haze),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Sparkline(values: values, color: AppColors.warm),
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
    );
  }
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

    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 1, size.width, 1.5),
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
        Paint()..color = latest ? AppColors.coldLit : AppColors.haze,
      );
    }

    if (mean > 0 && maxV > 0) {
      final y = size.height - 1 - (mean / denom) * (size.height - 6);
      final paint = Paint()
        ..color = AppColors.haze.withValues(alpha: .75)
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

class _TokenColumnsPainter extends CustomPainter {
  final List<int> inputTokens;
  final List<int> outputTokens;

  _TokenColumnsPainter({required this.inputTokens, required this.outputTokens});

  @override
  void paint(Canvas canvas, Size size) {
    final totals = [
      for (var i = 0; i < inputTokens.length; i++)
        inputTokens[i] + outputTokens[i],
    ];
    final maxV = totals.reduce(math.max);
    final denom = maxV <= 0 ? 1.0 : maxV.toDouble();
    final slot = size.width / totals.length;
    final barW = math.min(slot - 4, 22.0).clamp(2.0, 22.0);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 1, size.width, 1.5),
      Paint()..color = AppColors.rule,
    );
    for (var i = 0; i < totals.length; i++) {
      final totalH = ((totals[i] / denom) * (size.height - 6)).clamp(
        2.0,
        size.height - 4,
      );
      final inH = totals[i] == 0 ? 0.0 : (inputTokens[i] / totals[i]) * totalH;
      final outH = totalH - inH;
      final x = slot * i + (slot - barW) / 2;
      final latest = i == totals.length - 1;
      if (outH > 0.5) {
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(x, size.height - 1 - totalH, barW, outH),
            topLeft: const Radius.circular(1),
            topRight: const Radius.circular(1),
          ),
          Paint()..color = latest ? AppColors.coldLit : AppColors.haze,
        );
      }
      if (inH > 0.5) {
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(x, size.height - 1 - inH, barW, inH),
            topLeft: outH <= 0.5 ? const Radius.circular(1) : Radius.zero,
            topRight: outH <= 0.5 ? const Radius.circular(1) : Radius.zero,
          ),
          Paint()..color = latest ? AppColors.cold : AppColors.riser,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_TokenColumnsPainter old) =>
      old.inputTokens != inputTokens || old.outputTokens != outputTokens;
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
