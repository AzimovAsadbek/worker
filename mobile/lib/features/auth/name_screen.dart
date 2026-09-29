import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_error.dart';
import '../../core/l10n/strings.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';

/// First login: ask for a real name (foremen and employers see it).
class NameScreen extends ConsumerStatefulWidget {
  const NameScreen({super.key});
  @override
  ConsumerState<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends ConsumerState<NameScreen> {
  final _ctrl = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _ctrl.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.length < 2) {
      setState(() => _error = 'Ism kamida 2 harf bo\'lishi kerak');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(sessionProvider.notifier).updateName(name);
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 40),
            Text(S.nameTitle, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            const Text(S.nameSubtitle, style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 20),
            TextField(
              controller: _ctrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              maxLength: 120,
              style: const TextStyle(fontSize: 20),
              decoration: InputDecoration(hintText: S.nameHint, errorText: _error),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: _busy ? null : _save, child: const Text(S.next)),
          ],
        ),
      ),
    );
  }
}
