import 'package:flutter/material.dart';

import '../providers/registry.dart';
import '../providers/types.dart';
import '../services/usage_service.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

class AddAccountScreen extends StatefulWidget {
  const AddAccountScreen({super.key});

  @override
  State<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends State<AddAccountScreen> {
  String _providerId = providers.first.id;
  final _tokenController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      setState(() => _error = 'Paste a token first.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await addAccount(providerId: _providerId, token: token);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = providerById(_providerId);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Material(
        color: AppColors.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'New account',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w500,
                              letterSpacing: -1,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'Choose a provider, then verify its token.',
                            style: TextStyle(
                              color: AppColors.textDim,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      color: AppColors.textDim,
                      tooltip: 'Close',
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const Text(
                  'PLATFORM',
                  style: TextStyle(
                    color: AppColors.textDim,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                for (final option in providers) ...[
                  _providerOption(option),
                  if (option != providers.last) const SizedBox(height: 8),
                ],
                const SizedBox(height: 19),
                const Text(
                  'API KEY / TOKEN',
                  style: TextStyle(
                    color: AppColors.textDim,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _tokenController,
                  obscureText: true,
                  maxLines: 2,
                  autofocus: false,
                  decoration: InputDecoration(
                    hintText: _providerId == 'commandcode'
                        ? 'user_…'
                        : 'Paste access token',
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  provider?.howToGetToken ?? '',
                  style: const TextStyle(
                    color: AppColors.textDim,
                    fontSize: 10,
                    height: 1.45,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontSize: 11,
                    ),
                  ),
                ],
                const SizedBox(height: 19),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _busy ? null : _add,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.text,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: Text(_busy ? 'Verifying…' : 'Verify & add account'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _providerOption(AiProvider option) {
    final selected = option.id == _providerId;
    return OutlinedButton(
      onPressed: _busy
          ? null
          : () => setState(() {
              _providerId = option.id;
              _error = null;
            }),
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        backgroundColor: selected ? AppColors.accentSoft : AppColors.bgCard,
        foregroundColor: AppColors.text,
        side: BorderSide(
          color: selected ? AppColors.accent : AppColors.border,
          width: selected ? 1.5 : 1,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.all(12),
      ),
      child: Row(
        children: [
          ProviderAvatar(platform: option.id, size: 32),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  option.name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  option.id == 'commandcode'
                      ? 'user_… API key'
                      : 'access token',
                  style: const TextStyle(
                    color: AppColors.textDim,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          if (selected)
            const Icon(Icons.check, size: 18, color: AppColors.accent),
        ],
      ),
    );
  }
}
