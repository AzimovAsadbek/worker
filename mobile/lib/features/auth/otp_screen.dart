import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_error.dart';
import '../../core/l10n/strings.dart';
import '../../core/phone.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.phone});
  final String phone;
  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _ctrl = TextEditingController();
  String? _error;
  bool _busy = false;
  int _cooldown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCooldown(60);
  }

  void _startCooldown(int s) {
    _timer?.cancel();
    setState(() => _cooldown = s);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldown = _cooldown > 0 ? _cooldown - 1 : 0);
      if (_cooldown == 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _ctrl.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _error = '6 xonali kodni kiriting');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(sessionProvider.notifier).verifyOtp(widget.phone, code);
      // Router redirect takes over once the session is ready.
    } on ApiError catch (e) {
      setState(() => _error = e.message);
      _ctrl.clear();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    try {
      await ref.read(sessionProvider.notifier).requestOtp(widget.phone);
      _startCooldown(60);
      if (mounted) showSnack(context, 'Yangi kod yuborildi');
    } on ApiError catch (e) {
      final retry = e.details['retryAfterSeconds'];
      if (retry is num) _startCooldown(retry.toInt());
      if (mounted) showSnack(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(S.otpTitle, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(S.otpSent(prettyPhone(widget.phone)), style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 24),
            TextField(
              controller: _ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              autofillHints: const [AutofillHints.oneTimeCode],
              style: const TextStyle(fontSize: 30, letterSpacing: 14, fontWeight: FontWeight.w700),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
              decoration: InputDecoration(hintText: '••••••', errorText: _error, errorMaxLines: 3),
              onChanged: (v) {
                if (v.length == 6 && !_busy) _verify();
              },
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _verify,
              child: _busy ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : const Text(S.verify),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: _cooldown > 0 ? null : _resend, child: Text(_cooldown > 0 ? S.resendIn(_cooldown) : S.resend)),
            TextButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text(S.changeNumber)),
          ],
        ),
      ),
    );
  }
}
