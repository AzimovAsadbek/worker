import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_error.dart';
import '../../core/l10n/strings.dart';
import '../../core/phone.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';

class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key});
  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  final _ctrl = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final phone = normalizeUzPhone(_ctrl.text);
    if (phone == null) {
      setState(() => _error = S.invalidPhone);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(sessionProvider.notifier).requestOtp(phone);
      if (mounted) unawaited(context.push('/otp', extra: phone));
    } on ApiError catch (e) {
      // Cooldown means a code was already sent recently — let the user type it.
      if (e.code == 'OTP_COOLDOWN' && mounted) {
        unawaited(context.push('/otp', extra: phone));
      } else {
        setState(() => _error = e.message);
      }
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
            const SizedBox(height: 32),
            const Icon(Icons.engineering_rounded, size: 64, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(S.appName, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: 40),
            Text(S.loginTitle, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            const Text(S.loginSubtitle, style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 20),
            TextField(
              controller: _ctrl,
              autofocus: true,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              style: const TextStyle(fontSize: 22, letterSpacing: 1.2),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 +\-()]')), LengthLimitingTextInputFormatter(20)],
              decoration: InputDecoration(prefixText: '+998 ', hintText: S.phoneHint, errorText: _error, errorMaxLines: 3),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : const Text(S.getCode),
            ),
          ],
        ),
      ),
    );
  }
}
