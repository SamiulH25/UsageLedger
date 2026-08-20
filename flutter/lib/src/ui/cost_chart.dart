import 'package:flutter/material.dart';

import 'theme.dart';

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
    final chartH = 120.0;

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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          height: ((data[i].costUsd / denom) * chartH).clamp(2.0, chartH),
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (var i = 0; i < data.length; i++)
              Expanded(
                child: Text(
                  data[i].day.substring(5),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: const TextStyle(fontSize: 9, color: AppColors.textDim),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
