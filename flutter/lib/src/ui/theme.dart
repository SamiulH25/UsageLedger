import 'package:flutter/material.dart';

class AppColors {
  static const bg = Color(0xFFF4F2EA);
  static const bgElevated = Color(0xFFEAE8DF);
  static const bgCard = Color(0xFFFFFEFA);
  static const border = Color(0xFFDEDAD0);
  static const text = Color(0xFF25251F);
  static const textDim = Color(0xFF77766D);
  static const accent = Color(0xFF3A5F7D);
  static const accentSoft = Color(0xFFE1EDF3);
  static const accentBlue = Color(0xFF3A5F7D);
  static const danger = Color(0xFFBD654C);
  static const dangerSoft = Color(0xFFF6E6DF);
  static const warning = Color(0xFFC47A4D);
}

class AppSpacing {
  static const pageHorizontal = 16.0;
  static const pageBottom = 32.0;
  static const sectionGap = 20.0;
}

class AppText {
  static const brand = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.8,
    color: AppColors.text,
  );
  static const pageTitle = TextStyle(
    fontSize: 28,
    height: 1.02,
    letterSpacing: -1.2,
    fontWeight: FontWeight.w600,
    color: AppColors.text,
  );
  static const pageSubtitle = TextStyle(
    fontSize: 13,
    height: 1.45,
    color: AppColors.textDim,
  );
  static const sectionLabel = TextStyle(
    color: AppColors.textDim,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
  );
  static const eyebrow = TextStyle(
    color: AppColors.accent,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.6,
  );
}

/// Parse a `#RRGGBB` hex string into a [Color].
Color hexColor(String hex) {
  final clean = hex.replaceFirst('#', '');
  return Color(int.parse('FF$clean', radix: 16));
}

ThemeData buildTheme() {
  final base = ThemeData.light(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.accent,
      surface: AppColors.bgCard,
      onSurface: AppColors.text,
      outline: AppColors.border,
      error: AppColors.danger,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.text,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: AppColors.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.border),
      ),
      elevation: 0,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.bg,
      indicatorColor: AppColors.accentSoft,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          color: selected ? AppColors.accent : AppColors.textDim,
          fontSize: 11,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? AppColors.accent : AppColors.textDim,
        );
      }),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.bgCard,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      labelStyle: const TextStyle(color: AppColors.textDim, fontSize: 13),
      hintStyle: const TextStyle(color: AppColors.textDim, fontSize: 13),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.text,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
  if (n <= 0) return '\$0';
  return '\$${n.toStringAsFixed(2)}';
}

String fmtPct(double fraction) =>
    '${(fraction.clamp(0.0, 1.0) * 100).round()}%';

String fmtResetAt(int resetAt, {DateTime? now}) {
  if (resetAt <= 0) return '';
  now ??= DateTime.now();
  final when = DateTime.fromMillisecondsSinceEpoch(resetAt).toLocal();
  final diff = when.difference(now);
  if (diff.isNegative) {
    return diff.inHours.abs() < 2 ? 'resetting now' : 'reset overdue';
  }
  if (diff.inMinutes < 1) return 'resets now';
  if (diff.inMinutes < 60) return 'resets in ${diff.inMinutes}m';
  if (diff.inHours < 24) {
    final minutes = diff.inMinutes % 60;
    return minutes == 0
        ? 'resets in ${diff.inHours}h'
        : 'resets in ${diff.inHours}h ${minutes}m';
  }
  if (diff.inDays == 1) return 'resets tomorrow';
  if (diff.inDays < 7) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return 'resets ${days[when.weekday - 1]}';
  }
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return 'resets ${months[when.month - 1]} ${when.day}';
}

Color limitColor(double fraction, {bool exceeded = false}) {
  if (exceeded || fraction >= 0.9) return AppColors.danger;
  if (fraction >= 0.7) return AppColors.warning;
  return AppColors.accent;
}

String fmtAgo(int epochMs, {DateTime? now}) {
  if (epochMs <= 0) return '';
  now ??= DateTime.now();
  final diff = now.difference(DateTime.fromMillisecondsSinceEpoch(epochMs));
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'yesterday';
  return '${diff.inDays}d ago';
}
