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
      setState(() => _error = 'Paste an API key first.');
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
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('New account', style: AppText.pageTitle),
                          SizedBox(height: 6),
                          Text(
                            'Pick a provider, paste its API key, and we will verify it before saving.',
                            style: AppText.pageSubtitle,
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
                const Text('PLATFORM', style: AppText.sectionLabel),
                const SizedBox(height: 10),
                for (final option in providers) ...[
                  _providerOption(option),
                  if (option != providers.last) const SizedBox(height: 8),
                ],
                const SizedBox(height: 20),
                const Text('API KEY', style: AppText.sectionLabel),
                const SizedBox(height: 10),
                TextField(
                  controller: _tokenController,
                  obscureText: true,
                  maxLines: 2,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _busy ? null : _add(),
                  decoration: InputDecoration(
                    labelText: 'Paste API key',
                    hintText: _providerId == 'commandcode' ? 'user_…' : 'crsr_…',
                    helperText: provider?.howToGetToken ?? '',
                    helperMaxLines: 4,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  InlineMessage.error(_error!),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy ? null : _add,
                  child: Text(_busy ? 'Verifying…' : 'Verify & add account'),
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
    return Semantics(
      selected: selected,
      button: true,
      label: '${option.name} provider',
      child: OutlinedButton(
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
          minimumSize: const Size.fromHeight(56),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        child: Row(
          children: [
            ProviderAvatar(platform: option.id, size: 34),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    option.id == 'commandcode'
                        ? 'user_… API key'
                        : 'User API key',
                    style: const TextStyle(
                      color: AppColors.textDim,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, size: 20, color: AppColors.accent),
          ],
        ),
      ),
    );
  }
}
