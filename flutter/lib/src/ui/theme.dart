import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../providers/types.dart';

/// Horizon design tokens.
///
/// The app answers one question: how long until you hit a wall? So the ground
/// is a cold, unlit blue-slate and depletion is expressed as *heat* — a full
/// pool reads glacial, a draining pool warms, an empty one runs hot. Hue is
/// never decorative: if something is coloured, that colour is its status.
class AppColors {
  /// Page ground.
  static const abyss = Color(0xFF0A0F17);

  /// Card and sheet surface.
  static const deck = Color(0xFF131B26);

  /// Inset surface — gauge tracks, fields, chips.
  static const riser = Color(0xFF1C2735);

  /// Hairlines and dividers.
  static const rule = Color(0xFF2B3A4C);

  /// Primary text.
  static const beam = Color(0xFFE6EDF6);

  /// Secondary text and inactive icons.
  static const haze = Color(0xFF8497AD);

  // Thermal ramp — the only colours that carry meaning.
  /// Plenty left. Doubles as the interactive colour, since "go" and "healthy"
  /// are the same idea here.
  static const cold = Color(0xFF3FC1B8);
  static const coldLit = Color(0xFF7EE0D8);
  static const coldSoft = Color(0xFF102A2C);

  /// Getting thin.
  static const warm = Color(0xFFF0A93B);
  static const warmSoft = Color(0xFF2C2113);

  /// Empty or over the cap.
  static const hot = Color(0xFFFF6A5E);
  static const hotLit = Color(0xFFFF9188);
  static const hotSoft = Color(0xFF2E1614);
}

class AppSpacing {
  static const pageHorizontal = 18.0;
  static const pageTop = 14.0;
  static const pageBottom = 40.0;
  static const sectionGap = 26.0;
}

class AppRadius {
  static const card = 6.0;
  static const control = 5.0;
  static const track = 2.0;
}

class AppMotion {
  static const quick = Duration(milliseconds: 180);
  static const settle = Duration(milliseconds: 420);
  static const curve = Curves.easeOutCubic;

  /// Honour the OS "remove animations" setting everywhere motion is used.
  static bool enabled(BuildContext context) =>
      !MediaQuery.disableAnimationsOf(context);
}

/// Data face — numerals, timestamps, eyebrow labels.
const String monoFamily = 'JetBrainsMono';

/// Interface face. Variable: weight 100–900, width 62–125.
const String uiFamily = 'Archivo';

List<FontVariation> _axes(double weight, double width) => [
  FontVariation('wght', weight),
  FontVariation('wdth', width),
];

class AppText {
  /// Big instrument numerals. Wide and tightly tracked so a countdown reads
  /// like a departure board rather than a paragraph.
  static TextStyle readout(double size, {Color color = AppColors.beam}) =>
      TextStyle(
        fontFamily: uiFamily,
        fontVariations: _axes(780, 118),
        fontWeight: FontWeight.w800,
        fontSize: size,
        height: 1.0,
        letterSpacing: -size * 0.028,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static const brand = TextStyle(
    fontFamily: uiFamily,
    fontVariations: [FontVariation('wght', 700), FontVariation('wdth', 112)],
    fontWeight: FontWeight.w700,
    fontSize: 15,
    letterSpacing: 0.2,
    color: AppColors.beam,
  );

  static const pageTitle = TextStyle(
    fontFamily: uiFamily,
    fontVariations: [FontVariation('wght', 700), FontVariation('wdth', 110)],
    fontWeight: FontWeight.w700,
    fontSize: 24,
    height: 1.1,
    letterSpacing: -0.5,
    color: AppColors.beam,
  );

  static const cardTitle = TextStyle(
    fontFamily: uiFamily,
    fontVariations: [FontVariation('wght', 650), FontVariation('wdth', 104)],
    fontWeight: FontWeight.w600,
    fontSize: 14.5,
    height: 1.2,
    letterSpacing: -0.1,
    color: AppColors.beam,
  );

  /// Running prose — subtitles, help text, empty-state copy.
  static TextStyle body({
    double size = 13,
    Color color = AppColors.haze,
    FontWeight weight = FontWeight.w400,
  }) => TextStyle(
    fontFamily: uiFamily,
    fontVariations: _axes(weight == FontWeight.w400 ? 400 : 550, 100),
    fontWeight: weight,
    fontSize: size,
    height: 1.5,
    color: color,
  );

  static const pageSubtitle = TextStyle(
    fontFamily: uiFamily,
    fontVariations: [FontVariation('wght', 400), FontVariation('wdth', 100)],
    fontSize: 13,
    height: 1.5,
    color: AppColors.haze,
  );

  /// Tiny uppercase machine label.
  static TextStyle tag({Color color = AppColors.haze, double size = 10}) =>
      TextStyle(
        fontFamily: monoFamily,
        fontSize: size,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.5,
        height: 1.3,
        color: color,
      );

  /// Inline data values.
  static TextStyle data({
    double size = 12.5,
    FontWeight weight = FontWeight.w500,
    Color color = AppColors.beam,
    double spacing = 0,
    double height = 1.35,
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
    scaffoldBackgroundColor: AppColors.abyss,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.cold,
      onPrimary: AppColors.abyss,
      secondary: AppColors.warm,
      surface: AppColors.deck,
      onSurface: AppColors.beam,
      outline: AppColors.rule,
      error: AppColors.hot,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.abyss,
      foregroundColor: AppColors.beam,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleTextStyle: AppText.cardTitle,
    ),
    cardTheme: CardThemeData(
      color: AppColors.deck,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.rule),
      ),
      elevation: 0,
      margin: EdgeInsets.zero,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.rule,
      space: 1,
      thickness: 1,
    ),
    textTheme: base.textTheme.apply(
      fontFamily: uiFamily,
      bodyColor: AppColors.beam,
      displayColor: AppColors.beam,
    ),
    iconTheme: const IconThemeData(color: AppColors.haze, size: 20),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.abyss,
      indicatorColor: AppColors.coldSoft,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      surfaceTintColor: Colors.transparent,
      height: 66,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return AppText.tag(
          color: selected ? AppColors.coldLit : AppColors.haze,
          size: 9.5,
        ).copyWith(fontWeight: selected ? FontWeight.w700 : FontWeight.w500);
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          size: 21,
          color: selected ? AppColors.coldLit : AppColors.haze,
        );
      }),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.riser,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      border: _fieldBorder(AppColors.rule),
      enabledBorder: _fieldBorder(AppColors.rule),
      focusedBorder: _fieldBorder(AppColors.cold, width: 1.5),
      errorBorder: _fieldBorder(AppColors.hot),
      focusedErrorBorder: _fieldBorder(AppColors.hot, width: 1.5),
      labelStyle: AppText.body(size: 13),
      floatingLabelStyle: AppText.tag(color: AppColors.coldLit, size: 11),
      hintStyle: AppText.data(size: 12.5, color: AppColors.haze),
      helperStyle: AppText.body(size: 11.5),
      helperMaxLines: 3,
      errorStyle: AppText.body(size: 11.5, color: AppColors.hotLit),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.cold,
        foregroundColor: AppColors.abyss,
        disabledBackgroundColor: AppColors.riser,
        disabledForegroundColor: AppColors.haze,
        minimumSize: const Size(64, 50),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        textStyle: AppText.tag(size: 11.5).copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.beam,
        minimumSize: const Size(64, 50),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        side: const BorderSide(color: AppColors.rule),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        textStyle: AppText.tag(color: AppColors.beam, size: 11.5),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.coldLit,
        minimumSize: const Size(48, 44),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        textStyle: AppText.tag(color: AppColors.coldLit, size: 11),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.riser,
      contentTextStyle: AppText.body(size: 12.5, color: AppColors.beam),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        side: const BorderSide(color: AppColors.rule),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.deck,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.rule),
      ),
      titleTextStyle: AppText.cardTitle,
      contentTextStyle: AppText.body(size: 13),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.deck,
      modalBackgroundColor: AppColors.deck,
      surfaceTintColor: Colors.transparent,
      showDragHandle: false,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.riser,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        side: const BorderSide(color: AppColors.rule),
      ),
      textStyle: AppText.body(size: 13, color: AppColors.beam),
    ),
    expansionTileTheme: const ExpansionTileThemeData(
      backgroundColor: Colors.transparent,
      collapsedBackgroundColor: Colors.transparent,
      iconColor: AppColors.haze,
      collapsedIconColor: AppColors.haze,
      textColor: AppColors.beam,
      collapsedTextColor: AppColors.beam,
      shape: Border(),
      collapsedShape: Border(),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppColors.abyss
            : AppColors.haze,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) =>
            s.contains(WidgetState.selected) ? AppColors.cold : AppColors.riser,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(AppColors.rule),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: AppColors.haze,
      titleTextStyle: AppText.body(
        size: 13.5,
        color: AppColors.beam,
        weight: FontWeight.w500,
      ),
      subtitleTextStyle: AppText.body(size: 11.5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.cold,
      linearTrackColor: AppColors.riser,
      circularTrackColor: Colors.transparent,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.riser,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: AppColors.rule),
      ),
      textStyle: AppText.body(size: 11.5, color: AppColors.beam),
    ),
  );
}

OutlineInputBorder _fieldBorder(Color color, {double width = 1}) =>
    OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.control),
      borderSide: BorderSide(color: color, width: width),
    );

// ---------------------------------------------------------------------------
// Formatting
// ---------------------------------------------------------------------------

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

/// Dollars still in a capped pool. Uncapped windows return spent.
double windowRemaining(LimitWindow w) {
  if (w.cap <= 0) return 0;
  final left = w.cap - w.used;
  return left < 0 ? 0 : left;
}

String fmtLeft(LimitWindow w) {
  if (w.cap <= 0) return '${fmtCost(w.used)} spent';
  return '${fmtCost(windowRemaining(w))} left';
}

String fmtPct(double fraction) =>
    '${(fraction.clamp(0.0, 1.0) * 100).round()}%';

/// Compact duration for countdowns: `4d`, `18h 20m`, `47m`, `now`.
String fmtSpan(Duration d) {
  if (d.inSeconds <= 0) return 'now';
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  if (d.inHours < 24) {
    final minutes = d.inMinutes % 60;
    return minutes == 0 ? '${d.inHours}h' : '${d.inHours}h ${minutes}m';
  }
  final hours = d.inHours % 24;
  return hours == 0 ? '${d.inDays}d' : '${d.inDays}d ${hours}h';
}

/// Time until a window resets, or null when the provider gives no reset.
Duration? untilReset(LimitWindow w, {DateTime? now}) {
  if (w.resetAt <= 0) return null;
  now ??= DateTime.now();
  final diff = DateTime.fromMillisecondsSinceEpoch(w.resetAt).difference(now);
  return diff.isNegative ? Duration.zero : diff;
}

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
  if (diff.inDays == 1) {
    final hours = diff.inHours % 24;
    return hours == 0 ? 'resets tomorrow' : 'resets tomorrow · ${hours}h';
  }
  if (diff.inDays < 7) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final hours = diff.inHours % 24;
    return hours == 0
        ? 'resets ${days[when.weekday - 1]} · ${diff.inDays}d'
        : 'resets ${days[when.weekday - 1]} · ${diff.inDays}d ${hours}h';
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

// ---------------------------------------------------------------------------
// Thermal ramp
// ---------------------------------------------------------------------------

/// Fill colour for a pool that is [fraction] consumed.
Color limitColor(double fraction, {bool exceeded = false}) {
  if (exceeded || fraction >= 0.9) return AppColors.hot;
  if (fraction >= 0.8) return AppColors.warm;
  return AppColors.cold;
}

/// Text-weight variant of [limitColor], lifted for legibility on dark surfaces.
Color limitTextColor(double fraction, {bool exceeded = false}) {
  if (exceeded || fraction >= 0.9) return AppColors.hotLit;
  if (fraction >= 0.8) return AppColors.warm;
  return AppColors.coldLit;
}

/// Tinted background that pairs with [limitColor].
Color limitSoftColor(double fraction, {bool exceeded = false}) {
  if (exceeded || fraction >= 0.9) return AppColors.hotSoft;
  if (fraction >= 0.8) return AppColors.warmSoft;
  return AppColors.coldSoft;
}

/// Colour for a runway lane.
///
/// A gauge asks "how much is left"; a lane asks "does this survive its own
/// window". They are different questions, so a pool can legitimately be cold
/// on one and hot on the other — plenty left but burning far too fast, or
/// nearly empty but refilling in ten minutes.
Color runwayColor(double survivedFraction, {bool dry = false}) {
  if (dry) return AppColors.hot;
  if (survivedFraction >= 0.999) return AppColors.cold;
  return survivedFraction < 0.5 ? AppColors.hot : AppColors.warm;
}

Color runwayTextColor(double survivedFraction, {bool dry = false}) {
  if (dry) return AppColors.hotLit;
  if (survivedFraction >= 0.999) return AppColors.coldLit;
  return survivedFraction < 0.5 ? AppColors.hotLit : AppColors.warm;
}

/// One-word heat reading, used as the eyebrow on pool rows.
String heatLabel(double fraction, {bool exceeded = false}) {
  if (exceeded || fraction >= 1) return 'EMPTY';
  if (fraction >= 0.9) return 'CRITICAL';
  if (fraction >= 0.8) return 'LOW';
  if (fraction >= 0.5) return 'HALF';
  return 'HEALTHY';
}
