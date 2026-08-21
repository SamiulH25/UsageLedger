import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Daily spend bars — amber columns over a hairline baseline, mono labels.
class CostChart extends StatelessWidget {
  final List<({String day, double costUsd})> series;
  const CostChart({super.key, required this.series});

  @override
  Widget build(BuildContext context) {
    final data = series.length > 14 ? series.sublist(series.length - 14) : series;
    if (data.length < 2) {
      return const SizedBox(height: 0);
    }
    final maxV = data.map((e) => e.costUsd).reduce((a, b) => a > b ? a : b);
    final denom = maxV <= 0 ? 1.0 : maxV;
    final chartH = 110.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: chartH,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < data.length; i++)
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 26),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            width: double.infinity,
                            height:
                                ((data[i].costUsd / denom) * chartH).clamp(3.0, chartH),
                            decoration: BoxDecoration(
                              color: i == data.length - 1
                                  ? AppColors.accent
                                  : AppColors.accent.withValues(alpha: .45),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(3),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Container(height: 1, color: AppColors.border),
        const SizedBox(height: 5),
        Row(
          children: [
            for (var i = 0; i < data.length; i++)
              Expanded(
                child: Text(
                  data[i].day.substring(5),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: AppText.data(size: 8.5, color: AppColors.textDim),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Minimal polyline sparkline for per-account trend rows.
class Sparkline extends StatelessWidget {
  final List<double> values;
  final Color color;
  final double strokeWidth;

  const Sparkline({
    super.key,
    required this.values,
    this.color = AppColors.accent,
    this.strokeWidth = 1.6,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 36),
      painter: _SparklinePainter(
        values: values,
        color: color,
        strokeWidth: strokeWidth,
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

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = i / (values.length - 1) * size.width;
      final y = size.height - 2 - ((values[i] - minV) / span) * (size.height - 4);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paint);

    // End dot.
    final lastX = size.width;
    final lastY =
        size.height - 2 - ((values.last - minV) / span) * (size.height - 4);
    canvas.drawCircle(Offset(lastX - 2, lastY), 2.4, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}
