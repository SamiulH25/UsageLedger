import 'package:flutter/material.dart';

import '../providers/registry.dart';
import '../services/usage_service.dart';
import '../ui/theme.dart';

class AddAccountScreen extends StatefulWidget {
  const AddAccountScreen({super.key});

  @override
  State<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends State<AddAccountScreen> {
  String _providerId = providers.first.id;
  final _tokenCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _tokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final token = _tokenCtrl.text.trim();
    if (token.isEmpty) {
      setState(() => _error = 'Paste a token/key first.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await addAccount(providerId: _providerId, token: token);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add account')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Platform', style: TextStyle(color: AppColors.textDim, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final p in providers)
                ChoiceChip(
                  label: Text(p.name),
                  selected: _providerId == p.id,
                  onSelected: (_) => setState(() => _providerId = p.id),
                ),
            ],
          ),
          const SizedBox(height: 20),
          const Text('API key / token', style: TextStyle(color: AppColors.textDim, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: _tokenCtrl,
            obscureText: true,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: _providerId == 'commandcode' ? 'user_...' : 'paste token',
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                providerById(_providerId)?.howToGetToken ?? '',
                style: const TextStyle(color: AppColors.textDim, fontSize: 13, height: 1.4),
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
            ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _add,
            style: FilledButton.styleFrom(
              backgroundColor: hexColor(providerColor(_providerId)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(_busy ? 'Verifying…' : 'Verify & add'),
          ),
        ],
      ),
    );
  }
}
