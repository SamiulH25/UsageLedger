import 'package:flutter/material.dart';

import '../data/burn_rate.dart';
import '../providers/types.dart';
import '../state/app_scope.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// First run. Opens with the thing the app is actually for — a pool that runs
/// dry before it refills — rather than a list of promises.
class OnboardingScreen extends StatelessWidget {
  final Future<void> Function(bool openAddAccount) onDone;
  final Future<void> Function()? persistOnboarding;

  const OnboardingScreen({
    super.key,
    required this.onDone,
    this.persistOnboarding,
  });

  Future<void> _finish(
    BuildContext context, {
    required bool openAddAccount,
  }) async {
    if (persistOnboarding != null) {
      await persistOnboarding!();
    } else {
      final repo = AppScope.of(context).repository;
      await repo.setSettingValue('onboarded', '1');
    }
    await onDone(openAddAccount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 8),
                children: [
                  const AppBrandBar(),
                  const SizedBox(height: 30),
                  const PageHeading(
                    eyebrow: 'RUNWAY, NOT RECEIPTS',
                    title: 'Know before you\nhit the wall.',
                    subtitle:
                        'Every pool you pay for drains at some rate and '
                        'refills at some time. UsageLedger shows you which '
                        'one runs out first.',
                  ),
                  const SizedBox(height: 22),
                  const _RunwayDemo(),
                  const SizedBox(height: 22),
                  _point(
                    'Keys never leave this phone',
                    'They go into the Android keystore. Uninstalling the app '
                        'deletes them.',
                  ),
                  _point(
                    'Real limits, not guesses',
                    'Included allowances, credit balances and reset times, '
                        'read straight from each provider.',
                  ),
                  _point(
                    'A warning with time to react',
                    'At 80%, at 90%, and again when a pool is gone.',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => _finish(context, openAddAccount: true),
                      child: const Text('ADD AN ACCOUNT'),
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () => _finish(context, openAddAccount: false),
                    child: const Text('NOT NOW'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _point(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 34,
            margin: const EdgeInsets.only(top: 2, right: 13),
            color: AppColors.rule,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppText.body(
                    size: 13.5,
                    color: AppColors.beam,
                    weight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(body, style: AppText.body(size: 12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A worked example of the runway readout, using plausible numbers so the
/// shape of "this one dies early" is learned before any real data arrives.
class _RunwayDemo extends StatelessWidget {
  const _RunwayDemo();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().millisecondsSinceEpoch;
    RunwayEntry entry(
      String account,
      String label,
      double used,
      double cap,
      Duration resetIn,
      double perDay,
    ) {
      final window = LimitWindow(
        id: '$account:$label',
        label: label,
        used: used,
        cap: cap,
        resetAt: now + resetIn.inMilliseconds,
      );
      return RunwayEntry(
        accountLabel: account,
        window: window,
        outlook: PoolOutlook.forWindow(window, perDay),
      );
    }

    return ThermalCard(
      rail: AppColors.warm,
      padding: const EdgeInsets.fromLTRB(15, 8, 15, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RunwayLane(
            entry: entry(
              'Command Code',
              '5h window',
              7.4,
              10,
              const Duration(hours: 4, minutes: 10),
              20,
            ),
          ),
          const Divider(height: 1),
          RunwayLane(
            entry: entry(
              'OpenRouter',
              'Credits',
              6,
              50,
              const Duration(days: 21),
              1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The hatched stretch is time with nothing left. The top pool runs '
            'dry before it refills; the bottom one lasts.',
            style: AppText.body(size: 11.5),
          ),
        ],
      ),
    );
  }
}
