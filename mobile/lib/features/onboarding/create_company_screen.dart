import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/phone.dart';
import '../../core/providers.dart';
import '../../core/widgets/common.dart';
import '../../data/repository.dart';

class CreateCompanyScreen extends ConsumerStatefulWidget {
  const CreateCompanyScreen({super.key});
  @override
  ConsumerState<CreateCompanyScreen> createState() => _CreateCompanyScreenState();
}

class _CreateCompanyScreenState extends ConsumerState<CreateCompanyScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _region = TextEditingController();
  final _city = TextEditingController();
  final _phone = TextEditingController();

  @override
  void dispose() {
    for (final c in [_name, _region, _city, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _create() async {
    if (!_form.currentState!.validate()) return;
    final phone = _phone.text.trim().isEmpty ? null : normalizeUzPhone(_phone.text);
    final company = await runAction(context, () async {
      final c = await ref.read(repoProvider).createCompany({
        'name': _name.text.trim(),
        if (_region.text.trim().isNotEmpty) 'region': _region.text.trim(),
        if (_city.text.trim().isNotEmpty) 'city': _city.text.trim(),
        'phone': ?phone,
      });
      await ref.read(sessionProvider.notifier).refreshMe();
      return c;
    });
    if (company == null || !mounted) return;
    final me = ref.read(sessionProvider).me!;
    final membership = me.memberships.firstWhere((m) => m.company.id == company['id']);
    await ref.read(sessionProvider.notifier).switchContext(membership.id);
    if (mounted) context.go('/company/more/sites?onboarding=1');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(S.createCompany)),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: S.companyName, hintText: 'Masalan: Taraqqiyot Construction'),
              validator: (v) => (v?.trim().length ?? 0) < 2 ? S.required : null,
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _region, decoration: const InputDecoration(labelText: '${S.region} (${S.optional})', hintText: 'Namangan viloyati')),
            const SizedBox(height: 12),
            TextFormField(controller: _city, decoration: const InputDecoration(labelText: '${S.city} (${S.optional})')),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: '${S.phone} (${S.optional})', prefixText: '+998 '),
              validator: (v) => v == null || v.trim().isEmpty || normalizeUzPhone(v) != null ? null : S.invalidPhone,
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: _create, child: const Text(S.createCompany)),
          ],
        ),
      ),
    );
  }
}
