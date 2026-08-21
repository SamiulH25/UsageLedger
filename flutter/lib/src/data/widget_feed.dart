/// Feeds the Android home-screen widget with the most urgent budget pool.
/// No-op off Android.
library;

import 'dart:io';

import 'package:home_widget/home_widget.dart';

import '../providers/types.dart';
import '../ui/theme.dart';
import 'usage_repository.dart';

const _qualifiedName = 'dev.bob2142.ai_usage_monitor.UsageLedgerWidgetProvider';

Future<void> feedWidget(UsageRepository repo) async {
  if (!Platform.isAndroid) return;
  try {
    final accounts = await repo.overviews();
    final hasAccounts = accounts.isNotEmpty;

    // Same hero rule as the Overview gauge.
    LimitWindow? hero;
    final pools = <({String account, LimitWindow window})>[];
    for (final account in accounts) {
      for (final window in account.windows) {
        if (window.kind == LimitKind.extra || window.cap <= 0) continue;
        if (window.id.endsWith(':5h') && window.idle) continue;
        pools.add((account: account.account.label, window: window));
        if (hero == null || window.fraction > hero.fraction) hero = window;
      }
    }
    pools.sort((a, b) => b.window.fraction.compareTo(a.window.fraction));

    await HomeWidget.saveWidgetData<String>(
      'wl_label',
      hero?.label.toUpperCase() ??
          (hasAccounts ? 'NO USAGE YET' : 'ADD AN ACCOUNT'),
    );
    await HomeWidget.saveWidgetData<String>(
      'wl_pct',
      hero == null
          ? '--'
          : hero.cap > 0
          ? fmtCost((hero.cap - hero.used).clamp(0.0, hero.cap))
          : fmtPct(hero.fraction),
    );
    await HomeWidget.saveWidgetData<String>(
      'wl_used',
      hero == null
          ? hasAccounts
                ? 'Sync an account to start tracking'
                : 'Add an account to start tracking'
          : hero.cap > 0
          ? '${fmtLeft(hero)} · ${fmtPct(hero.fraction)} used'
          : '${fmtCost(hero.used)} spent',
    );
    await HomeWidget.saveWidgetData<String>(
      'wl_reset',
      hero == null ? '' : fmtResetAt(hero.resetAt),
    );
    final now = DateTime.now().toLocal();
    await HomeWidget.saveWidgetData<String>(
      'wl_updated',
      'updated ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
    );
    for (var i = 0; i < 3; i++) {
      final value = i < pools.length
          ? '${pools[i].account} · ${pools[i].window.label}  ${fmtLeft(pools[i].window)}'
          : '';
      await HomeWidget.saveWidgetData<String>('wl_pool_${i + 1}', value);
    }
    await HomeWidget.updateWidget(qualifiedAndroidName: _qualifiedName);
  } catch (_) {
    // Widget updates must never break a sync.
  }
}
