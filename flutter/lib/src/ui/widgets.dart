import 'package:flutter/material.dart';

import '../db/db.dart';
import '../providers/registry.dart';
import '../providers/types.dart';
import 'theme.dart';

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final Color? valueColor;
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.sub,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textDim),
          ),
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
          if (sub != null)
            Text(
              sub!,
              style: const TextStyle(fontSize: 10, color: AppColors.textDim),
            ),
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
  final bool exceeded;
  final double height;
  const LimitBar({
    super.key,
    required this.fraction,
    this.exceeded = false,
    this.height = 6,
  });

  @override
  Widget build(BuildContext context) {
    final f = fraction.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: f,
        minHeight: height,
        backgroundColor: AppColors.bgElevated,
        valueColor: AlwaysStoppedAnimation(limitColor(f, exceeded: exceeded)),
      ),
    );
  }
}

class ProviderAvatar extends StatelessWidget {
  final String platform;
  final double size;

  const ProviderAvatar({super.key, required this.platform, this.size = 35});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: hexColor(providerColor(platform)),
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: Text(
        providerIcon(platform),
        style: TextStyle(
          fontSize: size * .3,
          fontWeight: FontWeight.w800,
          color: AppColors.text,
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
      padding: const EdgeInsets.fromLTRB(2, 20, 2, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: const TextStyle(fontSize: 11, color: AppColors.textDim),
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
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        backgroundColor: AppColors.accentSoft,
        foregroundColor: AppColors.accent,
        side: const BorderSide(color: AppColors.accent),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        padding: const EdgeInsets.all(15),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.add, size: 19, color: Colors.white),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add another account',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 3),
                Text(
                  'Command Code or Cursor · stored securely',
                  style: TextStyle(fontSize: 10, color: AppColors.textDim),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 19),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String icon;
  final String title;
  final String hint;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.hint,
  });

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
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
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

class AttentionBanner extends StatelessWidget {
  final List<(String account, LimitWindow window)> items;
  const AttentionBanner({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final first = items.first;
    final more = items.length - 1;
    final reset = fmtResetAt(first.$2.resetAt);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6E6DF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE4C4B6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            first.$2.exceeded ? 'Limit reached' : 'Near a limit',
            style: const TextStyle(
              color: AppColors.danger,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: .4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${first.$1} · ${first.$2.label} is at ${fmtPct(first.$2.fraction)}'
            '${reset.isEmpty ? '' : ' · $reset'}'
            '${more > 0 ? ' · +$more more' : ''}',
            style: const TextStyle(fontSize: 12, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class AccountUsageCard extends StatelessWidget {
  final AccountRow account;
  final double costUsd;
  final int requests;
  final int inputTokens;
  final int outputTokens;
  final List<LimitWindow> windows;
  final int lastRefreshAt;
  final Widget? footer;

  const AccountUsageCard({
    super.key,
    required this.account,
    required this.costUsd,
    required this.requests,
    required this.inputTokens,
    required this.outputTokens,
    this.windows = const [],
    this.lastRefreshAt = 0,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final budgets = windows.where((w) => w.kind == LimitKind.budget).toList();
    final shares = windows.where((w) => w.kind == LimitKind.share).toList();
    final bursts = windows.where((w) => w.kind == LimitKind.burst).toList();
    final extras = windows.where((w) => w.kind == LimitKind.extra).toList();
    final ago = fmtAgo(lastRefreshAt);
    final tokenCount = inputTokens + outputTokens;

    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
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
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        [
                          providerName(account.platform),
                          if (ago.isNotEmpty) ago,
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10, color: AppColors.textDim),
                      ),
                    ],
                  ),
                ),
                Text(
                  fmtCost(costUsd),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            if (bursts.isNotEmpty || budgets.isNotEmpty || shares.isNotEmpty || extras.isNotEmpty) ...[
              const Divider(height: 22),
              for (final burst in bursts) _burstRow(burst),
              for (final budget in budgets) ...[
                _budgetRow(budget),
                const SizedBox(height: 12),
              ],
              if (shares.length >= 2) _shareRow(shares[0], shares[1]),
              if (shares.length == 1) _shareSolo(shares.first),
              for (final extra in extras) _extraRow(extra),
            ],
            if (tokenCount > 0 || requests > 0) ...[
              const SizedBox(height: 4),
              Text(
                [
                  if (tokenCount > 0) '${fmtTokens(tokenCount)} tokens',
                  if (requests > 0) '$requests requests',
                ].join(' · '),
                style: const TextStyle(fontSize: 10, color: AppColors.textDim),
              ),
            ],
            if (footer != null) footer!,
          ],
        ),
      ),
    );
  }

  Widget _budgetRow(LimitWindow window) {
    final reset = fmtResetAt(window.resetAt);
    final color = limitColor(window.fraction, exceeded: window.exceeded);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(window.label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              ),
              Text(
                '${fmtCost(window.used)} / ${fmtCost(window.cap)}',
                style: const TextStyle(fontSize: 10, color: AppColors.textDim, fontFeatures: [FontFeature.tabularFigures()]),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LimitBar(fraction: window.fraction, exceeded: window.exceeded),
          const SizedBox(height: 5),
          Row(
            children: [
              Text(
                window.exceeded ? 'Limit reached' : fmtPct(window.fraction),
                style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              if (reset.isNotEmpty)
                Text(reset, style: const TextStyle(fontSize: 10, color: AppColors.textDim)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _burstRow(LimitWindow window) {
    if (window.idle) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(window.label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            ),
            Text(
              '${fmtCost(window.cap)} ready',
              style: const TextStyle(fontSize: 10, color: AppColors.textDim),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _budgetRow(window),
    );
  }

  Widget _shareRow(LimitWindow left, LimitWindow right) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: _shareCell(left)),
          const SizedBox(width: 14),
          Expanded(child: _shareCell(right)),
        ],
      ),
    );
  }

  Widget _shareSolo(LimitWindow window) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _shareCell(window),
    );
  }

  Widget _shareCell(LimitWindow window) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(window.label, style: const TextStyle(fontSize: 10, color: AppColors.textDim)),
            ),
            Text(
              fmtPct(window.fraction),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: limitColor(window.fraction, exceeded: window.exceeded),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        LimitBar(fraction: window.fraction, exceeded: window.exceeded, height: 4),
        const SizedBox(height: 4),
        Text(
          'of included',
          style: const TextStyle(fontSize: 9, color: AppColors.textDim),
        ),
      ],
    );
  }

  Widget _extraRow(LimitWindow window) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Extra usage', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                SizedBox(height: 2),
                Text('Beyond included allowance', style: TextStyle(fontSize: 9, color: AppColors.textDim)),
              ],
            ),
          ),
          Text(fmtCost(window.used), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
