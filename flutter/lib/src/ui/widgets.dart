import 'package:flutter/material.dart';

import 'theme.dart';

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final Color? valueColor;
  const StatCard({super.key, required this.label, required this.value, this.sub, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textDim)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppColors.text,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (sub != null) Text(sub!, style: const TextStyle(fontSize: 10, color: AppColors.textDim)),
        ],
      ),
    );
  }
}

class StatRow extends StatelessWidget {
  final List<Widget> children;
  const StatRow({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 24),
          children[i],
        ],
      ],
    );
  }
}

class LimitBar extends StatelessWidget {
  final double fraction;
  const LimitBar({super.key, required this.fraction});

  @override
  Widget build(BuildContext context) {
    final f = fraction.clamp(0.0, 1.0);
    final color = f > 0.9 ? AppColors.danger : f > 0.7 ? Colors.amber : AppColors.accent;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: f,
        minHeight: 8,
        backgroundColor: AppColors.border,
        valueColor: AlwaysStoppedAnimation(color),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String icon;
  final String title;
  final String hint;
  const EmptyState({super.key, required this.icon, required this.title, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.text)),
            const SizedBox(height: 4),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.textDim),
            ),
          ],
        ),
      ),
    );
  }
}
