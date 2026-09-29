import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/providers.dart';
import '../../core/widgets/common.dart';
import '../../data/repository.dart';
import 'profile_screen.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});
  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _trade;
  late final TextEditingController _years;
  late final TextEditingController _city;
  late final TextEditingController _bio;

  @override
  void initState() {
    super.initState();
    final me = ref.read(sessionProvider).me;
    final p = me?.workerProfile;
    _name = TextEditingController(text: me?.fullName ?? '');
    _trade = TextEditingController(text: p?.primaryTrade ?? '');
    _years = TextEditingController(text: p?.experienceYears?.toString() ?? '');
    _city = TextEditingController(text: p?.city ?? '');
    _bio = TextEditingController(text: p?.bio ?? '');
  }

  @override
  void dispose() {
    for (final c in [_name, _trade, _years, _city, _bio]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final ok = await runAction(context, () async {
      final session = ref.read(sessionProvider.notifier);
      if (_name.text.trim() != (ref.read(sessionProvider).me?.fullName ?? '')) await session.updateName(_name.text.trim());
      await ref.read(repoProvider).saveProfile({
        if (_trade.text.trim().isNotEmpty) 'primaryTrade': _trade.text.trim(),
        if (_years.text.trim().isNotEmpty) 'selfReportedExperienceYears': int.parse(_years.text.trim()),
        if (_city.text.trim().isNotEmpty) 'city': _city.text.trim(),
        if (_bio.text.trim().isNotEmpty) 'bio': _bio.text.trim(),
      });
      await session.refreshMe();
      return true;
    }, success: 'Saqlandi');
    if (ok == true && mounted) {
      ref.invalidate(myIdentityProvider);
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(S.editProfile)),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(controller: _name, decoration: const InputDecoration(labelText: S.fullName), validator: (v) => (v?.trim().length ?? 0) < 2 ? S.required : null),
            const SizedBox(height: 12),
            TextFormField(controller: _trade, decoration: const InputDecoration(labelText: S.trade, hintText: "Masalan: G'isht teruvchi")),
            const SizedBox(height: 12),
            TextFormField(
              controller: _years,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
              decoration: const InputDecoration(labelText: S.experienceYears, helperText: "Bu o'zingiz kiritgan ma'lumot — tasdiqlangan tarixdan alohida ko'rsatiladi"),
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _city, decoration: const InputDecoration(labelText: S.city)),
            const SizedBox(height: 12),
            TextFormField(controller: _bio, maxLines: 3, maxLength: 1000, decoration: const InputDecoration(labelText: S.bio)),
            const SizedBox(height: 16),
            FilledButton(onPressed: _save, child: const Text(S.save)),
          ],
        ),
      ),
    );
  }
}
