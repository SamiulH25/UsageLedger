import 'package:flutter/material.dart';

class AppColors {
  static const bg = Color(0xFF0B0E14);
  static const bgElevated = Color(0xFF12161F);
  static const bgCard = Color(0xFF171C27);
  static const border = Color(0xFF232A38);
  static const text = Color(0xFFE8ECF4);
  static const textDim = Color(0xFF8B93A7);
  static const accent = Color(0xFF22C55E);
  static const accentBlue = Color(0xFF3B82F6);
  static const danger = Color(0xFFEF4444);
}

/// Parse a `#RRGGBB` hex string into a [Color].
Color hexColor(String hex) {
  final clean = hex.replaceFirst('#', '');
  return Color(int.parse('FF$clean', radix: 16));
}

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.accent,
      surface: AppColors.bgCard,
      onSurface: AppColors.text,
      outline: AppColors.border,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.text,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: AppColors.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.bgCard,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.accent),
      ),
    ),
  );
}

String fmtTokens(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(2)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
  return '$n';
}

String fmtCost(double n) {
  if (n >= 100) return '\$${n.toStringAsFixed(0)}';
  if (n >= 1) return '\$${n.toStringAsFixed(2)}';
  return '\$${n.toStringAsFixed(4)}';
}
