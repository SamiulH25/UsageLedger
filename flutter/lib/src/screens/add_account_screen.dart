import 'package:flutter/material.dart';

import '../providers/registry.dart';
import '../providers/types.dart';
import '../state/app_scope.dart';
import '../state/sync_controller.dart';
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
  bool _showToken = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tokenController.addListener(() => setState(() {}));
  }

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
      await AppScope.of(
        context,
      ).repository.addAccount(providerId: _providerId, token: token);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() => _error = conciseError(error.toString()));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = providerById(_providerId);
    final typed = _tokenController.text.trim();
    final mismatch =
        provider != null && typed.isNotEmpty && !provider.keyLooksValid(typed);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Material(
        color: AppColors.deck,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
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
                    width: 36,
                    height: 3,
                    decoration: BoxDecoration(
                      color: AppColors.rule,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: PageHeading(
                        title: 'Connect a provider',
                        subtitle:
                            'The key is checked against the provider before '
                            'anything is saved.',
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 20),
                      color: AppColors.haze,
                      tooltip: 'Close',
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text('PROVIDER', style: AppText.tag(size: 9.5)),
                const SizedBox(height: 11),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth < 300 ? 1 : 2;
                    final width =
                        (constraints.maxWidth - (columns - 1) * 8) / columns;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final option in providers)
                          SizedBox(
                            width: width,
                            child: _providerOption(option),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 22),
                Text('API KEY', style: AppText.tag(size: 9.5)),
                const SizedBox(height: 11),
                TextField(
                  controller: _tokenController,
                  maxLines: 1,
                  obscureText: !_showToken,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.done,
                  style: AppText.data(size: 13),
                  onSubmitted: (_) => _busy ? null : _add(),
                  decoration: InputDecoration(
                    labelText: 'Paste API key',
                    hintText: provider?.keyHint ?? '…',
                    helperText: provider?.howToGetToken ?? '',
                    helperMaxLines: 4,
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _showToken = !_showToken),
                      icon: Icon(
                        _showToken
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 19,
                      ),
                      tooltip: _showToken ? 'Hide API key' : 'Show API key',
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  InlineMessage.error(_error!),
                ] else if (mismatch) ...[
                  const SizedBox(height: 14),
                  InlineMessage.warn(
                    "That doesn't look like a typical ${provider.name} key "
                    '(expected ${provider.keyHint}) — it may still work.',
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy ? null : _add,
                  child: Text(_busy ? 'VERIFYING…' : 'VERIFY AND ADD'),
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
      child: InkWell(
        onTap: _busy
            ? null
            : () => setState(() {
                _providerId = option.id;
                _error = null;
              }),
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: Container(
          padding: const EdgeInsets.fromLTRB(11, 11, 11, 11),
          constraints: const BoxConstraints(minHeight: 56),
          decoration: BoxDecoration(
            color: selected ? AppColors.coldSoft : AppColors.riser,
            borderRadius: BorderRadius.circular(AppRadius.control),
            border: Border.all(
              color: selected ? AppColors.cold : AppColors.rule,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              ProviderAvatar(platform: option.id, size: 28),
              const SizedBox(width: 10),
              Expanded(
                // The key hint lives in the field below once a provider is
                // picked, so the tile only carries the name and can give it
                // both lines.
                child: Text(
                  option.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(
                    size: 12.5,
                    color: AppColors.beam,
                    weight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
