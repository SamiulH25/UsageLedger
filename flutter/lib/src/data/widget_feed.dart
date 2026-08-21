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

    // Same hero rule as the Overview gauge.
    LimitWindow? hero;
    for (final account in accounts) {
      for (final window in account.windows) {
        if (window.kind == LimitKind.extra || window.cap <= 0) continue;
        if (hero == null || window.fraction > hero.fraction) hero = window;
      }
    }

    await HomeWidget.saveWidgetData<String>(
      'wl_label',
      hero?.label.toUpperCase() ?? 'NEXT WALL',
    );
    await HomeWidget.saveWidgetData<String>(
      'wl_pct',
      hero == null ? '--' : '${(hero.fraction * 100).round()}%',
    );
    await HomeWidget.saveWidgetData<String>(
      'wl_used',
      hero == null
          ? 'Sync to track your pools'
          : '${fmtCost(hero.used)} / ${fmtCost(hero.cap)}',
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
    await HomeWidget.updateWidget(qualifiedAndroidName: _qualifiedName);
  } catch (_) {
    // Widget updates must never break a sync.
  }
}
