import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Instrument-cluster design tokens.
///
/// The app reads like a cockpit: dark blue-slate panels, hairline separators,
/// monospaced numerals, and a warm amber signal color that is *semantic* —
/// amber means "approaching a limit", red means "gone", green means "fine".
class AppColors {
  static const bg = Color(0xFF0C1117);
  static const surface = Color(0xFF131A23);
  static const surfaceHi = Color(0xFF1A232E);
  static const border = Color(0xFF263241);
  static const text = Color(0xFFE6EDF5);
  static const textDim = Color(0xFF8494A7);
  static const accent = Color(0xFFF0A63C); // instrument amber
  static const accentSoft = Color(0xFF2A2318); // amber-tinted panel
  static const ok = Color(0xFF58B380);
  static const okSoft = Color(0xFF16241C);
  static const danger = Color(0xFFE06452);
  static const dangerSoft = Color(0xFF2A1B18);
}

class AppSpacing {
  static const pageHorizontal = 16.0;
  static const pageBottom = 32.0;
  static const sectionGap = 20.0;
}

/// Data face — every numeral, timestamp and eyebrow label.
const String monoFamily = 'JetBrainsMono';
/// Display face — headings and the brand.
const String displayFamily = 'SpaceGrotesk';

class AppText {
  static const brand = TextStyle(
    fontFamily: displayFamily,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.4,
    color: AppColors.text,
  );
  static const pageTitle = TextStyle(
    fontFamily: displayFamily,
    fontSize: 27,
    height: 1.05,
    letterSpacing: -0.6,
    fontWeight: FontWeight.w700,
    color: AppColors.text,
  );
  static const pageSubtitle = TextStyle(
    fontSize: 13,
    height: 1.45,
    color: AppColors.textDim,
  );
  static const sectionLabel = TextStyle(
    fontFamily: monoFamily,
    color: AppColors.textDim,
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.4,
  );
  static const eyebrow = TextStyle(
    fontFamily: monoFamily,
    color: AppColors.accent,
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.4,
  );

  /// Big hero numerals.
  static TextStyle heroNumber({Color color = AppColors.text}) => TextStyle(
    fontFamily: monoFamily,
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: -1,
    color: color,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  /// Inline data values.
  static TextStyle data({
    double size = 13,
    FontWeight weight = FontWeight.w500,
    Color color = AppColors.text,
    double spacing = 0,
    double height = 1.3,
  }) => TextStyle(
    fontFamily: monoFamily,
    fontSize: size,
    fontWeight: weight,
    letterSpacing: spacing,
    height: height,
    color: color,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
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
      surface: AppColors.surface,
      onSurface: AppColors.text,
      outline: AppColors.border,
      error: AppColors.danger,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.text,
      elevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      elevation: 0,
      margin: EdgeInsets.zero,
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
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontFamily: monoFamily,
          color: selected ? AppColors.accent : AppColors.textDim,
          fontSize: 10,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          letterSpacing: 0.3,
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
      fillColor: AppColors.surfaceHi,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      labelStyle: const TextStyle(color: AppColors.textDim, fontSize: 13),
      hintStyle: const TextStyle(
        color: AppColors.textDim,
        fontSize: 13,
        fontFamily: monoFamily,
      ),
      helperStyle: const TextStyle(color: AppColors.textDim, fontSize: 11, height: 1.4),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.bg,
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(
          fontFamily: monoFamily,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.surfaceHi,
      contentTextStyle: const TextStyle(color: AppColors.text, fontSize: 13),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      modalBackgroundColor: AppColors.surface,
      showDragHandle: false,
    ),
    expansionTileTheme: const ExpansionTileThemeData(
      backgroundColor: Colors.transparent,
      collapsedBackgroundColor: Colors.transparent,
      iconColor: AppColors.textDim,
      collapsedIconColor: AppColors.textDim,
      textColor: AppColors.text,
      collapsedTextColor: AppColors.text,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? AppColors.bg : AppColors.textDim,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? AppColors.accent : AppColors.border,
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
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return 'resets ${months[when.month - 1]} ${when.day}';
}

Color limitColor(double fraction, {bool exceeded = false}) {
  if (exceeded || fraction >= 0.9) return AppColors.danger;
  if (fraction >= 0.7) return AppColors.accent;
  return AppColors.ok;
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
