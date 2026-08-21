import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../db/db.dart';
import '../providers/registry.dart';
import '../providers/types.dart';
import '../state/app_scope.dart';
import 'theme.dart';

// ---------------------------------------------------------------------------
// Signature element: the pool gauge.
//
// Every budget window is drawn as an instrument meter — a tick-marked track,
// a fill in its semantic color, and (when burn rate says so) a caret marking
// where the level will sit when the window resets.
// ---------------------------------------------------------------------------

class PoolGauge extends StatelessWidget {
  final LimitWindow window;
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
    final caret = paceCaretFraction?.clamp(0.0, 1.0);

    final semanticStatus = window.cap > 0
        ? '${fmtPct(f)} used, ${fmtLeft(window)}'
        : '${fmtCost(window.used)} spent, uncapped';
    final semanticReset = reset.isEmpty ? '' : ', $reset';

    return Semantics(
      container: true,
      label: '${window.label}: $semanticStatus$semanticReset.',
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
                    window.label.toUpperCase(),
                    style: AppText.sectionLabel.copyWith(color: AppColors.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  window.cap > 0 ? fmtLeft(window) : fmtCost(window.used),
                  style: AppText.data(size: 11, color: AppColors.textDim),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _GaugeTrack(
              fraction: f,
              color: color,
              caretFraction: caret,
              height: compact ? 8 : 12,
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                Text(
                  window.exceeded
                      ? 'EMPTY'
                      : window.cap > 0
                      ? '${fmtPct(f)} used'
                      : 'UNCAPPED',
                  style: AppText.data(
                    size: 10,
                    weight: FontWeight.w700,
                    color: textColor,
                    spacing: 0.6,
                  ),
                ),
                const Spacer(),
                if (reset.isNotEmpty)
                  Text(
                    reset,
                    style: AppText.data(size: 10, color: AppColors.textDim),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GaugeTrack extends StatelessWidget {
  final double fraction;
  final Color color;
  final double? caretFraction;
  final double height;

  const _GaugeTrack({
    required this.fraction,
    required this.color,
    required this.height,
    this.caretFraction,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        Widget ticks = Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 1; i < 10; i++)
              Container(
                width: 1,
                height: height * 0.55,
                color: AppColors.border.withValues(alpha: .7),
              ),
          ],
        );
        return SizedBox(
          height: height,
          width: width,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Track
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surfaceHi,
                  borderRadius: BorderRadius.circular(height / 2),
                  border: Border.all(color: AppColors.border),
                ),
                child: const SizedBox.expand(),
              ),
              // Fill
              FractionallySizedBox(
                widthFactor: math.max(fraction, 0.004),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(height / 2),
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
              // Tick marks over everything
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: height * .55),
                  child: ticks,
                ),
              ),
              // Pace caret
              if (caretFraction != null && caretFraction! > fraction + 0.01)
                Positioned(
                  left: width * caretFraction! - 4,
                  top: -3,
                  child: Column(
                    children: [
                      Icon(
                        Icons.play_arrow_rounded,
                        size: height + 2,
                        color: AppColors.textDim,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
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
    final color = limitColor(f, exceeded: exceeded);
    final textColor = limitTextColor(f, exceeded: exceeded);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppText.data(size: 10, color: AppColors.textDim),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              fmtPct(f),
              style: AppText.data(
                size: 10,
                weight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: f,
            minHeight: 4,
            backgroundColor: AppColors.surfaceHi,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Structure & chrome
// ---------------------------------------------------------------------------

class StatCell extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const StatCell({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.sectionLabel),
        const SizedBox(height: 3),
        Text(
          value,
          style: AppText.data(
            size: 15,
            weight: FontWeight.w700,
            color: valueColor ?? AppColors.text,
          ),
        ),
      ],
    );
  }
}

class StatRow extends StatelessWidget {
  final List<Widget> children;
  const StatRow({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 330) {
          final width = (constraints.maxWidth - 16) / 2;
          return Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              for (final child in children)
                SizedBox(width: width, child: child),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (final child in children) Expanded(child: child)],
        );
      },
    );
  }
}

class ProviderAvatar extends StatelessWidget {
  final String platform;
  final double size;

  const ProviderAvatar({super.key, required this.platform, this.size = 35});

  @override
  Widget build(BuildContext context) {
    final asset = providerIconAsset(platform);
    return Semantics(
      label: '${providerName(platform)} logo',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surfaceHi,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: AppColors.border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: size,
            height: size,
            child: asset != null
                ? Image.asset(asset, fit: BoxFit.cover)
                : Center(
                    child: Text(
                      platform.isNotEmpty ? platform[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: size * .38,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDim,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Brand row with optional trailing actions (sync button etc).
class AppBrandBar extends StatelessWidget {
  final List<Widget>? actions;

  const AppBrandBar({super.key, this.actions});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Text('UsageLedger', style: AppText.brand)),
        if (actions != null) ...actions!,
      ],
    );
  }
}

/// Brand row with the live sync chip — used on every tab.
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
          if (onOpenSettings != null)
            IconButton(
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings_outlined, size: 19),
              color: AppColors.textDim,
              tooltip: 'Settings',
            ),
        ],
      ),
    );
  }
}

/// Mono status chip: SYNCED 2M AGO / SYNCING… / AUTO OFF.
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
        ? 'SYNCING…'
        : failed
        ? 'SYNC FAILED'
        : lastSuccessAt == null
        ? 'NOT SYNCED'
        : 'SYNCED ${_ago(lastSuccessAt!).toUpperCase()}';
    final color = syncing
        ? AppColors.accent
        : failed
        ? AppColors.dangerText
        : AppColors.textDim;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: ActionChip(
        onPressed: syncing ? null : onTap,
        backgroundColor: Colors.transparent,
        side: BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        visualDensity: VisualDensity.standard,
        tooltip: failed ? 'Retry sync' : 'Sync now',
        avatar: syncing
            ? SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.6,
                  color: color,
                ),
              )
            : Icon(Icons.satellite_alt_outlined, size: 13, color: color),
        label: Text(
          label,
          style: AppText.data(
            size: 9.5,
            weight: FontWeight.w600,
            color: color,
            spacing: 0.8,
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
  final Widget? trailing;

  const PageHeading({
    super.key,
    required this.title,
    this.subtitle,
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
              Text(title, style: AppText.pageTitle),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
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
  final Color background;
  final Color border;
  final Color foreground;

  /// Optional trailing action (e.g. "Update key").
  final Widget? action;

  const InlineMessage({
    super.key,
    required this.message,
    required this.icon,
    required this.background,
    required this.border,
    required this.foreground,
    this.action,
  });

  factory InlineMessage.error(String message, {Widget? action}) =>
      InlineMessage(
        message: message,
        icon: Icons.error_outline,
        background: AppColors.dangerSoft,
        border: AppColors.danger.withValues(alpha: .4),
        foreground: AppColors.dangerText,
        action: action,
      );

  factory InlineMessage.info(String message) => InlineMessage(
    message: message,
    icon: Icons.info_outline,
    background: AppColors.accentSoft,
    border: AppColors.accent.withValues(alpha: .35),
    foreground: AppColors.accent,
  );

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (action != null) ...[const SizedBox(width: 8), action!],
            ],
          ),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;

  const SectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 22, 2, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            title.toUpperCase(),
            style: AppText.sectionLabel.copyWith(fontSize: 11),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: AppText.data(size: 10, color: AppColors.textDim),
            ),
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
      label: 'Add another account',
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.text,
          side: const BorderSide(color: AppColors.border),
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.add_circle_outline,
              size: 20,
              color: AppColors.accent,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add account',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Any connected provider · key stays on device',
                    style: TextStyle(fontSize: 11, color: AppColors.textDim),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: AppColors.textDim),
          ],
        ),
      ),
    );
  }
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
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
      child: Column(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surfaceHi,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Icon(icon, size: 28, color: AppColors.textDim),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: displayFamily,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(hint, textAlign: TextAlign.center, style: AppText.pageSubtitle),
          if (action != null) ...[const SizedBox(height: 18), action!],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Account card (Overview + Accounts tabs)
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
    final bursts = windows.where((w) => w.kind == LimitKind.burst).toList()
      ..sort((a, b) => b.fraction.compareTo(a.fraction));
    final extras = windows.where((w) => w.kind == LimitKind.extra).toList();
    final ago = fmtAgo(lastRefreshAt);
    final tokenCount = inputTokens + outputTokens;

    final body = Column(
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
                    style: const TextStyle(
                      fontFamily: displayFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    [
                      providerName(account.platform).toUpperCase(),
                      if (account.syncError.isNotEmpty) 'SYNC FAILED',
                      if (ago.isNotEmpty && account.syncError.isEmpty) ago,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.data(
                      size: 9.5,
                      color: account.syncError.isNotEmpty
                          ? AppColors.dangerText
                          : AppColors.textDim,
                      spacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: Text(
                fmtCost(costUsd),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: AppText.data(size: 17, weight: FontWeight.w700),
              ),
            ),
            if (onOpen != null) ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.textDim,
              ),
            ],
          ],
        ),
        if (account.platform == 'cursor' && costUsd <= 0 && tokenCount > 0) ...[
          const SizedBox(height: 10),
          Text(
            'Tokens only — Cursor no longer reports per-request dollars on self-serve plans.',
            style: AppText.data(size: 10.5, color: AppColors.accent),
          ),
        ],
        if (banner != null) ...[const SizedBox(height: 10), banner!],
        if (bursts.isNotEmpty ||
            budgets.isNotEmpty ||
            shares.isNotEmpty ||
            extras.isNotEmpty) ...[
          const SizedBox(height: 14),
          for (final budget in budgets.take(2)) ...[
            PoolGauge(window: budget, compact: true),
            const SizedBox(height: 12),
          ],
          for (final burst in bursts)
            if (!burst.idle) ...[
              PoolGauge(window: burst, compact: true),
              const SizedBox(height: 12),
            ],
          if (shares.length >= 2)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
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
              ),
            )
          else if (shares.length == 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: ShareBar(
                label: shares.first.label,
                fraction: shares.first.fraction,
                exceeded: shares.first.exceeded,
              ),
            ),
          for (final extra in extras)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('EXTRA USAGE', style: AppText.sectionLabel),
                  ),
                  Text(
                    fmtCost(extra.used),
                    style: AppText.data(size: 11, weight: FontWeight.w700),
                  ),
                ],
              ),
            ),
        ],
        if (tokenCount > 0 || requests > 0) ...[
          const SizedBox(height: 8),
          Text(
            [
              if (tokenCount > 0) '${fmtTokens(tokenCount)} tok',
              if (requests > 0) '$requests req',
            ].join('  ·  '),
            style: AppText.data(size: 10, color: AppColors.textDim),
          ),
        ],
        if (models.isNotEmpty) ...[
          const SizedBox(height: 6),
          ModelBreakdownPanel(models: models, platform: account.platform),
        ],
        if (footer != null) footer!,
      ],
    );

    if (onOpen == null) {
      return Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
          child: body,
        ),
      );
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
          child: body,
        ),
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
    final totalCost = models.fold<double>(
      0,
      (sum, model) => sum + model.costUsd,
    );

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 4),
        expandedAlignment: Alignment.centerLeft,
        showTrailingIcon: true,
        title: Text(
          'MODEL USAGE',
          style: AppText.sectionLabel.copyWith(color: AppColors.text),
        ),
        subtitle: Text(
          '${models.length} models · ${fmtCost(totalCost)}',
          style: AppText.data(size: 10, color: AppColors.textDim),
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
    final groupCost = items.fold<double>(
      0,
      (sum, model) => sum + model.costUsd,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                title,
                style: AppText.sectionLabel.copyWith(color: AppColors.accent),
              ),
              const Spacer(),
              Text(
                fmtCost(groupCost),
                style: AppText.data(size: 10, color: AppColors.textDim),
              ),
            ],
          ),
          const SizedBox(height: 6),
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
                  style: AppText.data(size: 11, weight: FontWeight.w600),
                ),
                if (model.totalTokens > 0)
                  Text(
                    _tokenSplit(model),
                    style: AppText.data(size: 10, color: AppColors.textDim),
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
                style: AppText.data(size: 11, weight: FontWeight.w700),
              ),
              Text(
                fmtPct(share),
                style: AppText.data(size: 10, color: AppColors.textDim),
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
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('API KEY', style: AppText.sectionLabel),
          const SizedBox(height: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surfaceHi,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _revealed ? widget.apiKey : _masked,
                      style: AppText.data(
                        size: 11,
                        color: AppColors.textDim,
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
                    icon: const Icon(Icons.copy, size: 18),
                    tooltip: 'Copy API key',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
