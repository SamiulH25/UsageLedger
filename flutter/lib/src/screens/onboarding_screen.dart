import 'package:flutter/material.dart';

import '../state/app_scope.dart';
import '../ui/theme.dart';

/// First-run privacy pitch. Keys never leave the phone.
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('LEFT', style: AppText.eyebrow),
              const SizedBox(height: 8),
              const Text(
                'See what is left\nbefore a pool runs out.',
                style: AppText.pageTitle,
              ),
              const SizedBox(height: 12),
              Text(
                'UsageLedger pings each provider with the key you paste. '
                'Keys stay on this phone. Nothing is uploaded.',
                style: AppText.pageSubtitle,
              ),
              const SizedBox(height: 28),
              _point(
                'Keys on device',
                'Stored locally. Uninstall removes them.',
              ),
              _point(
                'Live limits',
                'Included pools, credits, and reset times from the APIs.',
              ),
              _point(
                'Alerts before empty',
                'A warning at 80% and 90%, then when a pool is gone.',
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => _finish(context, openAddAccount: true),
                  child: const Text('Add an account'),
                ),
              ),
              TextButton(
                onPressed: () => _finish(context, openAddAccount: false),
                child: const Text('Not now'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _point(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppText.data(size: 14, weight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(body, style: AppText.data(size: 12, color: AppColors.textDim)),
        ],
      ),
    );
  }
}
