import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/burn_rate.dart';
import '../db/db.dart';
import '../providers/registry.dart';
import '../providers/types.dart';
import '../state/app_scope.dart';
import 'theme.dart';

// ---------------------------------------------------------------------------
// Signature element: the runway lane.
//
// Each lane is one pool's own window, normalised so the reset always sits at
// the far right. The fill runs as far as the current burn rate will carry you.
// A bar that reaches the edge means you make it; a bar that stops short leaves
// a dead zone, and the width of that gap is how long you are stuck with
// nothing. Trouble is therefore a *shape*, readable without numbers.
// ---------------------------------------------------------------------------

/// A pool paired with the burn-rate projection for it.
class RunwayEntry {
  final String accountLabel;
  final LimitWindow window;
  final PoolOutlook outlook;

  const RunwayEntry({
    required this.accountLabel,
    required this.window,
    required this.outlook,
  });

  /// Fraction of the window the current pace carries you through.
  /// 1.0 means the pool outlasts the window.
  double get survivedFraction {
    final toReset = outlook.daysToReset;
    if (toReset == null || toReset <= 0) return 1;
    if (window.exceeded || window.fraction >= 1) return 0;
    final toEmpty = outlook.daysToEmpty;
    if (toEmpty == null) return 1;
    return (toEmpty / toReset).clamp(0.0, 1.0);
  }

  /// How long before the reset the pool runs dry, or null if it survives.
  Duration? get dryEarlyBy {
    final toReset = outlook.daysToReset;
    final toEmpty = outlook.daysToEmpty;
    if (toReset == null || toEmpty == null || toEmpty >= toReset) return null;
    return Duration(
      milliseconds: (((toReset - toEmpty) * 86400000).round()).clamp(
        0,
        1 << 52,
      ),
    );
  }

  /// Time left before the wall: empty-at-pace, or the reset if already dry.
  Duration? get timeToWall {
    if (window.exceeded || window.fraction >= 1) return Duration.zero;
    final toEmpty = outlook.daysToEmpty;
    if (toEmpty == null) return null;
    final toReset = outlook.daysToReset;
    if (toReset != null && toEmpty >= toReset) return null;
    return Duration(
      milliseconds: ((toEmpty * 86400000).round()).clamp(0, 1 << 52),
    );
  }

  bool get pending => outlook.daysToReset == null;
}

class RunwayLane extends StatelessWidget {
  final RunwayEntry entry;

  /// Hides the account name when the surrounding card already names it.
  final bool showAccount;

  const RunwayLane({super.key, required this.entry, this.showAccount = true});

  @override
  Widget build(BuildContext context) {
    final window = entry.window;
    final dry = window.exceeded || window.fraction >= 1;
    final survived = entry.survivedFraction;
    final color = runwayColor(survived, dry: dry);
    final early = entry.dryEarlyBy;
    final reset = untilReset(window);

    final String verdict;
    final Color verdictColor;
    if (dry) {
      verdict = reset == null ? 'empty' : 'empty · back in ${fmtSpan(reset)}';
      verdictColor = AppColors.hotLit;
    } else if (entry.pending || entry.outlook.daysToEmpty == null) {
      verdict = 'pace unknown';
      verdictColor = AppColors.haze;
    } else if (early == null) {
      verdict = 'lasts to reset';
      verdictColor = AppColors.coldLit;
    } else {
      verdict = 'dry ${fmtSpan(early)} early';
      verdictColor = runwayTextColor(survived);
    }

    final title = showAccount
        ? '${entry.accountLabel} · ${window.label}'
        : window.label;

    return Semantics(
      container: true,
      label:
          '$title. ${fmtLeft(window)}. $verdict.'
          '${reset == null ? '' : ' Resets in ${fmtSpan(reset)}.'}',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.data(
                        size: 12,
                        weight: FontWeight.w700,
                        color: AppColors.beam,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    fmtLeft(window),
                    style: AppText.data(size: 12, color: AppColors.haze),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              _RunwayTrack(
                survived: survived,
                color: color,
                unknown: entry.pending || entry.outlook.daysToEmpty == null,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      verdict,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.data(
                        size: 10.5,
                        weight: FontWeight.w600,
                        color: verdictColor,
                      ),
                    ),
                  ),
                  if (reset != null)
                    Text(
                      'reset ${fmtSpan(reset)}',
                      style: AppText.data(size: 10.5, color: AppColors.haze),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The lane itself: live fill, dead zone, and the reset gate at the right edge.
class _RunwayTrack extends StatelessWidget {
  final double survived;
  final Color color;
  final bool unknown;

  const _RunwayTrack({
    required this.survived,
    required this.color,
    required this.unknown,
  });

  @override
  Widget build(BuildContext context) {
    const height = 12.0;
    final animate = AppMotion.enabled(context);
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: animate ? 0 : survived, end: survived),
            duration: animate ? AppMotion.settle : Duration.zero,
            curve: AppMotion.curve,
            builder: (context, value, _) => CustomPaint(
              size: Size(width, height),
              painter: _RunwayPainter(
                survived: value,
                color: color,
                unknown: unknown,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RunwayPainter extends CustomPainter {
  final double survived;
  final Color color;
  final bool unknown;

  _RunwayPainter({
    required this.survived,
    required this.color,
    required this.unknown,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const gate = 3.0;
    final laneW = size.width - gate - 4;
    final radius = Radius.circular(AppRadius.track);

    // Bed.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, laneW, size.height),
        radius,
      ),
      Paint()..color = AppColors.riser,
    );

    if (unknown) {
      _paintHatch(canvas, Rect.fromLTWH(0, 0, laneW, size.height));
    } else {
      final liveW = laneW * survived.clamp(0.0, 1.0);

      // Dead zone: the stretch after the pool runs dry, hatched so it reads as
      // unusable rather than merely unfilled.
      if (survived < 0.999) {
        canvas.save();
        canvas.clipRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(0, 0, laneW, size.height),
            radius,
          ),
        );
        _paintHatch(
          canvas,
          Rect.fromLTWH(liveW, 0, laneW - liveW, size.height),
        );
        canvas.restore();
      }

      if (liveW > 0.5) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(0, 0, liveW, size.height),
            radius,
          ),
          Paint()..color = color,
        );
        // Bright meniscus at the level, so the edge reads as a liquid surface.
        if (survived < 0.999) {
          canvas.drawRect(
            Rect.fromLTWH(liveW - 2, 0, 2, size.height),
            Paint()..color = Color.lerp(color, Colors.white, 0.45)!,
          );
        }
      }
    }

    // Reset gate: the finish line the fill is racing towards.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width - gate, -1, gate, size.height + 2),
        const Radius.circular(1),
      ),
      Paint()..color = survived >= 0.999 ? color : AppColors.haze,
    );
  }

  void _paintHatch(Canvas canvas, Rect rect) {
    if (rect.width <= 0) return;
    canvas.save();
    canvas.clipRect(rect);
    final paint = Paint()
      ..color = AppColors.rule
      ..strokeWidth = 1;
    for (var x = rect.left - rect.height; x < rect.right; x += 5) {
      canvas.drawLine(
        Offset(x, rect.bottom),
        Offset(x + rect.height, rect.top),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RunwayPainter old) =>
      old.survived != survived || old.color != color || old.unknown != unknown;
}

// ---------------------------------------------------------------------------
// Pool gauge — how much is left, as opposed to how long it lasts.
// ---------------------------------------------------------------------------

class PoolGauge extends StatelessWidget {
  final LimitWindow window;

  /// Where the level lands at reset if the current pace holds.
  final double? paceCaretFraction;
  final bool compact;

  const PoolGauge({
    super.key,
    required this.window,
    this.paceCaretFraction,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final f = window.fraction.clamp(0.0, 1.0);
    final color = limitColor(f, exceeded: window.exceeded);
    final textColor = limitTextColor(f, exceeded: window.exceeded);
    final reset = fmtResetAt(window.resetAt);

    final semanticStatus = window.cap > 0
        ? '${fmtPct(f)} used, ${fmtLeft(window)}'
        : '${fmtCost(window.used)} spent, uncapped';

    return Semantics(
      container: true,
      label:
          '${window.label}: $semanticStatus${reset.isEmpty ? '' : ', $reset'}.',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    window.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.data(
                      size: compact ? 11.5 : 12.5,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  window.cap > 0 ? fmtLeft(window) : fmtCost(window.used),
                  style: AppText.data(size: 11.5, color: AppColors.haze),
                ),
              ],
            ),
            SizedBox(height: compact ? 5 : 7),
            Meter(
              fraction: f,
              color: color,
              height: compact ? 6 : 9,
              caretFraction: paceCaretFraction,
            ),
            SizedBox(height: compact ? 4 : 6),
            Row(
              children: [
                Text(
                  window.cap > 0
                      ? heatLabel(f, exceeded: window.exceeded)
                      : 'UNCAPPED',
                  style: AppText.tag(color: textColor, size: 9.5),
                ),
                const Spacer(),
                if (reset.isNotEmpty)
                  Flexible(
                    child: Text(
                      reset,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: AppText.data(size: 10.5, color: AppColors.haze),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A single filled track. Animates to its value and honours reduced motion.
class Meter extends StatelessWidget {
  final double fraction;
  final Color color;
  final double height;
  final double? caretFraction;

  const Meter({
    super.key,
    required this.fraction,
    required this.color,
    this.height = 8,
    this.caretFraction,
  });

  @override
  Widget build(BuildContext context) {
    final animate = AppMotion.enabled(context);
    final target = fraction.clamp(0.0, 1.0);
    return SizedBox(
      height: height,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: animate ? 0 : target, end: target),
        duration: animate ? AppMotion.settle : Duration.zero,
        curve: AppMotion.curve,
        builder: (context, value, _) => CustomPaint(
          size: Size(double.infinity, height),
          painter: _MeterPainter(
            fraction: value,
            color: color,
            caret: caretFraction?.clamp(0.0, 1.0),
          ),
        ),
      ),
    );
  }
}

class _MeterPainter extends CustomPainter {
  final double fraction;
  final Color color;
  final double? caret;

  _MeterPainter({required this.fraction, required this.color, this.caret});

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(AppRadius.track);
    final bed = RRect.fromRectAndRadius(Offset.zero & size, radius);
    canvas.drawRRect(bed, Paint()..color = AppColors.riser);

    final fillW = size.width * fraction;
    if (fillW > 0.5) {
      canvas.save();
      canvas.clipRRect(bed);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, fillW, size.height),
        Paint()..color = color,
      );
      if (fraction < 0.995) {
        canvas.drawRect(
          Rect.fromLTWH(fillW - 1.5, 0, 1.5, size.height),
          Paint()..color = Color.lerp(color, Colors.white, 0.5)!,
        );
      }
      canvas.restore();
    }

    // Projected level at reset — a notch, not a second bar, so it never
    // competes with the actual reading.
    final c = caret;
    if (c != null && c > fraction + 0.02) {
      final x = (size.width * c).clamp(0.0, size.width - 1);
      canvas.drawRect(
        Rect.fromLTWH(x - 0.75, -2, 1.5, size.height + 4),
        Paint()..color = AppColors.haze,
      );
    }
  }

  @override
  bool shouldRepaint(_MeterPainter old) =>
      old.fraction != fraction || old.color != color || old.caret != caret;
}

/// Tiny inline share bar (Auto/API slices of one pool).
class ShareBar extends StatelessWidget {
  final String label;
  final double fraction;
  final bool exceeded;

  const ShareBar({
    super.key,
    required this.label,
    required this.fraction,
    this.exceeded = false,
  });

  @override
  Widget build(BuildContext context) {
    final f = fraction.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.data(size: 10.5, color: AppColors.haze),
              ),
            ),
            Text(
              fmtPct(f),
              style: AppText.data(
                size: 10.5,
                weight: FontWeight.w700,
                color: limitTextColor(f, exceeded: exceeded),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Meter(
          fraction: f,
          color: limitColor(f, exceeded: exceeded),
          height: 4,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Surfaces
// ---------------------------------------------------------------------------

/// The card language for the whole app: a hairline box with a thermal rail
/// down its left edge. Scanning the rails alone tells you where the trouble
/// is, before any number is read.
class ThermalCard extends StatelessWidget {
  final Widget child;
  final Color? rail;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final Color? background;

  const ThermalCard({
    super.key,
    required this.child,
    this.rail,
    this.padding = const EdgeInsets.fromLTRB(15, 14, 15, 14),
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.background,
  });

  static const _railWidth = 3.0;

  @override
  Widget build(BuildContext context) {
    final railColor = rail ?? AppColors.rule;
    Widget content = Padding(
      padding: const EdgeInsets.only(left: _railWidth).add(padding),
      child: child,
    );
    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: railColor.withValues(alpha: .08),
          highlightColor: railColor.withValues(alpha: .05),
          child: content,
        ),
      );
    }
    return Padding(
      padding: margin,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background ?? AppColors.deck,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.rule),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card - 1),
          // Stack rather than a stretched Row: the rail must span whatever
          // height the content ends up at, including inside a scroll view
          // where the height is unbounded.
          child: Stack(
            children: [
              content,
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: SizedBox(
                  width: _railWidth,
                  child: ColoredBox(color: railColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Big instrument reading: eyebrow, numeral, and a line of context.
class Readout extends StatelessWidget {
  final String eyebrow;
  final String value;
  final String? detail;
  final Color color;
  final double size;

  const Readout({
    super.key,
    required this.eyebrow,
    required this.value,
    this.detail,
    this.color = AppColors.beam,
    this.size = 46,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$eyebrow: $value.${detail == null ? '' : ' $detail'}',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(eyebrow, style: AppText.tag(color: color)),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: AppText.readout(size, color: color)),
            ),
            if (detail != null) ...[
              const SizedBox(height: 8),
              Text(
                detail!,
                style: AppText.data(size: 11.5, color: AppColors.haze),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Label/value pairs separated by hairlines.
class MetricRow extends StatelessWidget {
  final List<Metric> metrics;

  const MetricRow({super.key, required this.metrics});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stack = constraints.maxWidth < 250 && metrics.length > 2;
        if (stack) {
          return Column(
            children: [
              for (var i = 0; i < metrics.length; i++) ...[
                if (i > 0)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(height: 1),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(metrics[i].label, style: AppText.tag()),
                    Text(
                      metrics[i].value,
                      style: AppText.data(
                        size: 14,
                        weight: FontWeight.w700,
                        color: metrics[i].color ?? AppColors.beam,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < metrics.length; i++) ...[
                if (i > 0)
                  const VerticalDivider(
                    width: 21,
                    thickness: 1,
                    color: AppColors.rule,
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        metrics[i].label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.tag(),
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          metrics[i].value,
                          style: AppText.data(
                            size: 15,
                            weight: FontWeight.w700,
                            color: metrics[i].color ?? AppColors.beam,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class Metric {
  final String label;
  final String value;
  final Color? color;
  const Metric(this.label, this.value, {this.color});
}

class ProviderAvatar extends StatelessWidget {
  final String platform;
  final double size;

  const ProviderAvatar({super.key, required this.platform, this.size = 34});

  @override
  Widget build(BuildContext context) {
    final asset = providerIconAsset(platform);
    return Semantics(
      label: '${providerName(platform)} logo',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.riser,
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: Border.all(color: AppColors.rule),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.control - 1),
          child: SizedBox(
            width: size,
            height: size,
            child: asset != null
                ? Image.asset(asset, fit: BoxFit.cover)
                : Center(
                    child: Text(
                      platform.isNotEmpty ? platform[0].toUpperCase() : '?',
                      style: AppText.data(
                        size: size * .38,
                        weight: FontWeight.w700,
                        color: AppColors.haze,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chrome
// ---------------------------------------------------------------------------

/// Wordmark plus trailing actions.
class AppBrandBar extends StatelessWidget {
  final List<Widget>? actions;

  const AppBrandBar({super.key, this.actions});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 15,
          margin: const EdgeInsets.only(right: 9),
          color: AppColors.cold,
        ),
        const Expanded(child: Text('UsageLedger', style: AppText.brand)),
        if (actions != null) ...actions!,
      ],
    );
  }
}

/// Wordmark with the live sync status — used on every tab.
class BrandBarWithSync extends StatelessWidget {
  final VoidCallback? onOpenSettings;

  const BrandBarWithSync({super.key, this.onOpenSettings});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: scope.sync,
      builder: (context, _) => AppBrandBar(
        actions: [
          SyncChip(
            lastAttemptAt: scope.sync.lastAttemptAt,
            lastSuccessAt: scope.sync.lastSuccessAt,
            syncing: scope.sync.syncing,
            failed: scope.sync.syncFailed,
            onTap: () => scope.sync.sync(),
          ),
          if (onOpenSettings != null) ...[
            const SizedBox(width: 2),
            IconButton(
              onPressed: onOpenSettings,
              icon: const Icon(Icons.tune, size: 19),
              color: AppColors.haze,
              tooltip: 'Settings',
            ),
          ],
        ],
      ),
    );
  }
}

/// Status pill: SYNCED 2M AGO / SYNCING… / SYNC FAILED.
class SyncChip extends StatelessWidget {
  final DateTime? lastAttemptAt;
  final DateTime? lastSuccessAt;
  final bool syncing;
  final bool failed;
  final VoidCallback onTap;

  const SyncChip({
    super.key,
    required this.lastAttemptAt,
    required this.lastSuccessAt,
    required this.syncing,
    required this.failed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = syncing
        ? 'SYNCING'
        : failed
        ? 'SYNC FAILED'
        : lastSuccessAt == null
        ? 'NOT SYNCED'
        : _ago(lastSuccessAt!).toUpperCase();
    final color = syncing
        ? AppColors.coldLit
        : failed
        ? AppColors.hotLit
        : AppColors.haze;

    return Tooltip(
      message: failed ? 'Retry sync' : 'Sync now',
      child: Semantics(
        button: true,
        label: failed
            ? 'Sync failed. Retry sync.'
            : syncing
            ? 'Syncing'
            : 'Synced $label. Sync now.',
        child: ExcludeSemantics(
          child: InkWell(
            onTap: syncing ? null : onTap,
            borderRadius: BorderRadius.circular(AppRadius.control),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44, minWidth: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 9),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (syncing)
                      SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.6,
                          color: color,
                        ),
                      )
                    else
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: failed ? AppColors.hot : AppColors.cold,
                          shape: BoxShape.circle,
                        ),
                      ),
                    const SizedBox(width: 7),
                    Text(label, style: AppText.tag(color: color, size: 9.5)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _ago(DateTime when) {
    final diff = DateTime.now().difference(when);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class PageHeading extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? eyebrow;
  final Widget? trailing;

  const PageHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.eyebrow,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null) ...[
                Text(eyebrow!, style: AppText.tag(color: AppColors.coldLit)),
                const SizedBox(height: 8),
              ],
              Text(title, style: AppText.pageTitle),
              if (subtitle != null) ...[
                const SizedBox(height: 7),
                Text(subtitle!, style: AppText.pageSubtitle),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class InlineMessage extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color tone;
  final Color background;

  /// Optional trailing action (e.g. "Update key").
  final Widget? action;

  const InlineMessage({
    super.key,
    required this.message,
    required this.icon,
    required this.tone,
    required this.background,
    this.action,
  });

  factory InlineMessage.error(String message, {Widget? action}) =>
      InlineMessage(
        message: message,
        icon: Icons.priority_high_rounded,
        tone: AppColors.hotLit,
        background: AppColors.hotSoft,
        action: action,
      );

  factory InlineMessage.info(String message, {Widget? action}) =>
      InlineMessage(
        message: message,
        icon: Icons.info_outline_rounded,
        tone: AppColors.coldLit,
        background: AppColors.coldSoft,
        action: action,
      );

  factory InlineMessage.warn(String message, {Widget? action}) =>
      InlineMessage(
        message: message,
        icon: Icons.warning_amber_rounded,
        tone: AppColors.warm,
        background: AppColors.warmSoft,
        action: action,
      );

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: Border.all(color: tone.withValues(alpha: .3)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 17, color: tone),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    message,
                    style: AppText.body(size: 12.5, color: tone),
                  ),
                ),
              ),
              if (action != null) ...[const SizedBox(width: 6), action!],
            ],
          ),
        ),
      ),
    );
  }
}

/// Section divider: a rule with the title sitting on it.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;

  const SectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, AppSpacing.sectionGap, 0, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title.toUpperCase(),
            style: AppText.tag(color: AppColors.beam, size: 10.5),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Divider(height: 1)),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            Text(trailing!, style: AppText.data(size: 10, color: AppColors.haze)),
          ],
        ],
      ),
    );
  }
}

class AddAccountCard extends StatelessWidget {
  final VoidCallback onPressed;

  const AddAccountCard({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Add an account',
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: DottedEdge(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 15, 14, 15),
                child: Row(
                  children: [
                    const Icon(Icons.add, size: 19, color: AppColors.coldLit),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add an account',
                            style: AppText.body(
                              size: 13.5,
                              color: AppColors.beam,
                              weight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'The key stays on this phone',
                            style: AppText.body(size: 11.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dashed hairline box — reserved for "nothing here yet, put something here".
class DottedEdge extends StatelessWidget {
  final Widget child;
  const DottedEdge({super.key, required this.child});

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _DashedBorderPainter(),
    child: child,
  );
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.rule
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(.5, .5, size.width - 1, size.height - 1),
      Radius.circular(AppRadius.card),
    );
    final metrics = Path()..addRRect(rrect);
    for (final metric in metrics.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final end = (d + 4).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(d, end), paint);
        d += 8;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) => false;
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String hint;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.hint,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: AppColors.haze),
          const SizedBox(height: 16),
          Text(title, style: AppText.pageTitle.copyWith(fontSize: 19)),
          const SizedBox(height: 7),
          Text(hint, style: AppText.pageSubtitle),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    );
  }
}

/// Placeholder bar used while the first load is in flight.
class SkeletonBar extends StatelessWidget {
  final double height;
  final double widthFactor;

  const SkeletonBar({super.key, this.height = 12, this.widthFactor = 1});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: widthFactor,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: AppColors.riser,
            borderRadius: BorderRadius.circular(AppRadius.track),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Account card
// ---------------------------------------------------------------------------

class AccountUsageCard extends StatelessWidget {
  final AccountRow account;
  final double costUsd;
  final int requests;
  final int inputTokens;
  final int outputTokens;
  final List<LimitWindow> windows;
  final List<ModelUsage> models;
  final int lastRefreshAt;
  final VoidCallback? onOpen;
  final Widget? footer;

  /// Rendered under the header when the last sync failed (re-auth nudge).
  final Widget? banner;

  const AccountUsageCard({
    super.key,
    required this.account,
    required this.costUsd,
    required this.requests,
    required this.inputTokens,
    required this.outputTokens,
    this.windows = const [],
    this.models = const [],
    this.lastRefreshAt = 0,
    this.onOpen,
    this.footer,
    this.banner,
  });

  @override
  Widget build(BuildContext context) {
    final budgets = windows.where((w) => w.kind == LimitKind.budget).toList()
      ..sort((a, b) => b.fraction.compareTo(a.fraction));
    final shares = windows.where((w) => w.kind == LimitKind.share).toList();
    final bursts =
        windows.where((w) => w.kind == LimitKind.burst && !w.idle).toList()
          ..sort((a, b) => b.fraction.compareTo(a.fraction));
    final extras = windows.where((w) => w.kind == LimitKind.extra).toList();
    final gauges = [...budgets.take(2), ...bursts];
    final ago = fmtAgo(lastRefreshAt);
    final tokenCount = inputTokens + outputTokens;
    final failed = account.syncError.isNotEmpty;

    // The rail carries the account's worst pool, so a column of cards reads as
    // a single health scan.
    final hottest = [...budgets, ...bursts].isEmpty
        ? null
        : [...budgets, ...bursts].reduce(
            (a, b) => a.fraction >= b.fraction ? a : b,
          );
    final rail = failed
        ? AppColors.hot
        : hottest == null
        ? AppColors.rule
        : limitColor(hottest.fraction, exceeded: hottest.exceeded);

    return ThermalCard(
      margin: const EdgeInsets.only(bottom: 10),
      rail: rail,
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProviderAvatar(platform: account.platform),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.cardTitle,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        providerName(account.platform).toUpperCase(),
                        if (failed) 'SYNC FAILED',
                        if (ago.isNotEmpty && !failed) ago.toUpperCase(),
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.tag(
                        color: failed ? AppColors.hotLit : AppColors.haze,
                        size: 9,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  fmtCost(costUsd),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: AppText.data(size: 16, weight: FontWeight.w700),
                ),
              ),
              if (onOpen != null)
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppColors.haze,
                ),
            ],
          ),
          if (account.platform == 'cursor' && costUsd <= 0 && tokenCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Tokens only — Cursor no longer reports per-request dollars '
                'on self-serve plans.',
                style: AppText.body(size: 11.5, color: AppColors.warm),
              ),
            ),
          if (banner != null) ...[const SizedBox(height: 11), banner!],
          if (gauges.isNotEmpty) ...[
            const SizedBox(height: 14),
            for (var i = 0; i < gauges.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              PoolGauge(window: gauges[i], compact: true),
            ],
          ],
          if (shares.isNotEmpty) ...[
            const SizedBox(height: 12),
            if (shares.length >= 2)
              Row(
                children: [
                  Expanded(
                    child: ShareBar(
                      label: shares[0].label,
                      fraction: shares[0].fraction,
                      exceeded: shares[0].exceeded,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ShareBar(
                      label: shares[1].label,
                      fraction: shares[1].fraction,
                      exceeded: shares[1].exceeded,
                    ),
                  ),
                ],
              )
            else
              ShareBar(
                label: shares.first.label,
                fraction: shares.first.fraction,
                exceeded: shares.first.exceeded,
              ),
          ],
          for (final extra in extras)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text('EXTRA USAGE', style: AppText.tag(size: 9.5)),
                  ),
                  Text(
                    fmtCost(extra.used),
                    style: AppText.data(
                      size: 11.5,
                      weight: FontWeight.w700,
                      color: AppColors.warm,
                    ),
                  ),
                ],
              ),
            ),
          if (tokenCount > 0 || requests > 0)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                [
                  if (tokenCount > 0) '${fmtTokens(tokenCount)} tok',
                  if (requests > 0) '$requests req',
                ].join('   '),
                style: AppText.data(size: 10.5, color: AppColors.haze),
              ),
            ),
          if (models.isNotEmpty)
            ModelBreakdownPanel(models: models, platform: account.platform),
          if (footer != null) footer!,
        ],
      ),
    );
  }
}

class ModelBreakdownPanel extends StatelessWidget {
  final List<ModelUsage> models;
  final String platform;

  const ModelBreakdownPanel({
    super.key,
    required this.models,
    required this.platform,
  });

  @override
  Widget build(BuildContext context) {
    final totalCost = models.fold<double>(0, (sum, m) => sum + m.costUsd);

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 4),
        expandedAlignment: Alignment.centerLeft,
        showTrailingIcon: true,
        title: Text(
          'MODEL USAGE',
          style: AppText.tag(color: AppColors.beam, size: 9.5),
        ),
        subtitle: Text(
          '${models.length} models · ${fmtCost(totalCost)}',
          style: AppText.data(size: 10.5, color: AppColors.haze),
        ),
        children: platform == 'cursor'
            ? [
                if (_bucket(models, 'auto').isNotEmpty)
                  _groupSection('AUTO', _bucket(models, 'auto'), totalCost),
                if (_bucket(models, 'api').isNotEmpty)
                  _groupSection('API', _bucket(models, 'api'), totalCost),
                if (_unbucketed(models).isNotEmpty)
                  _groupSection('OTHER', _unbucketed(models), totalCost),
              ]
            : [_modelList(models, totalCost)],
      ),
    );
  }

  List<ModelUsage> _bucket(List<ModelUsage> items, String bucket) =>
      items.where((model) => model.bucket == bucket).toList()
        ..sort((a, b) => b.costUsd.compareTo(a.costUsd));

  List<ModelUsage> _unbucketed(List<ModelUsage> items) =>
      items.where((model) => model.bucket == null).toList()
        ..sort((a, b) => b.costUsd.compareTo(a.costUsd));

  Widget _groupSection(String title, List<ModelUsage> items, double totalCost) {
    final groupCost = items.fold<double>(0, (sum, m) => sum + m.costUsd);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(title, style: AppText.tag(color: AppColors.coldLit, size: 9.5)),
              const SizedBox(width: 10),
              const Expanded(child: Divider(height: 1)),
              const SizedBox(width: 10),
              Text(
                fmtCost(groupCost),
                style: AppText.data(size: 10.5, color: AppColors.haze),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map((model) => _modelRow(model, totalCost)),
        ],
      ),
    );
  }

  Widget _modelList(List<ModelUsage> items, double totalCost) {
    final sorted = [...items]..sort((a, b) => b.costUsd.compareTo(a.costUsd));
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        children: sorted.map((model) => _modelRow(model, totalCost)).toList(),
      ),
    );
  }

  String _tokenSplit(ModelUsage model) {
    final parts = <String>[
      if (model.inputTokens > 0) '${fmtTokens(model.inputTokens)} in',
      if (model.outputTokens > 0) '${fmtTokens(model.outputTokens)} out',
      if (model.cacheReadTokens > 0)
        '${fmtTokens(model.cacheReadTokens)} cache r',
      if (model.cacheWriteTokens > 0)
        '${fmtTokens(model.cacheWriteTokens)} cache w',
    ];
    return parts.isEmpty
        ? '${fmtTokens(model.totalTokens)} tok'
        : parts.join(' · ');
  }

  Widget _modelRow(ModelUsage model, double totalCost) {
    final share = totalCost > 0 ? model.costUsd / totalCost : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  model.model,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.data(size: 11.5, weight: FontWeight.w600),
                ),
                if (model.totalTokens > 0)
                  Text(
                    _tokenSplit(model),
                    style: AppText.data(size: 10, color: AppColors.haze),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                fmtCost(model.costUsd),
                style: AppText.data(size: 11.5, weight: FontWeight.w700),
              ),
              Text(
                fmtPct(share),
                style: AppText.data(size: 10, color: AppColors.haze),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ApiKeyPanel extends StatefulWidget {
  final String apiKey;

  const ApiKeyPanel({super.key, required this.apiKey});

  @override
  State<ApiKeyPanel> createState() => _ApiKeyPanelState();
}

class _ApiKeyPanelState extends State<ApiKeyPanel> {
  bool _revealed = false;

  String get _masked {
    final key = widget.apiKey;
    if (key.length <= 4) return '••••';
    return '•••• ${key.substring(key.length - 4)}';
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.apiKey));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('API key copied')));
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.riser,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: AppColors.rule),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _revealed ? widget.apiKey : _masked,
                style: AppText.data(
                  size: 11.5,
                  color: AppColors.haze,
                  height: 1.45,
                ),
              ),
            ),
            IconButton(
              onPressed: () => setState(() => _revealed = !_revealed),
              icon: Icon(
                _revealed
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 18,
              ),
              tooltip: _revealed ? 'Hide key' : 'Show key',
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              onPressed: _copy,
              icon: const Icon(Icons.copy_rounded, size: 17),
              tooltip: 'Copy API key',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}
