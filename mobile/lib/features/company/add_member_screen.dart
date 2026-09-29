import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/phone.dart';
import '../../core/widgets/common.dart';
import '../../data/repository.dart';
import '../../models/models.dart';
import 'company_providers.dart';

class AddMemberScreen extends ConsumerStatefulWidget {
  const AddMemberScreen({super.key});
  @override
  ConsumerState<AddMemberScreen> createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends ConsumerState<AddMemberScreen> {
  final _form = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _name = TextEditingController();
  final _title = TextEditingController();
  String _role = 'WORKER';
  final Set<String> _sites = {};
  bool _resident = false;

  @override
  void dispose() {
    for (final c in [_phone, _name, _title]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final m = ref.read(activeMembershipProvider)!;
    if (m.role == Role.foreman && _sites.isEmpty) {
      showSnack(context, 'Kamida bitta obyektni tanlang', error: true);
      return;
    }
    final ok = await runAction(
      context,
      () async {
        await ref.read(repoProvider).addMember(
              cidFrom(ref),
              phone: normalizeUzPhone(_phone.text)!,
              fullName: _name.text.trim(),
              role: _role,
              title: _title.text.trim(),
              siteIds: _sites.toList(),
              isResident: _resident,
            );
        return true;
      },
      success: "Qo'shildi. U shu raqam bilan ilovaga kirishi mumkin.",
    );
    if (ok == true && mounted) {
      ref.invalidate(dashboardProvider);
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = ref.watch(activeMembershipProvider);
    final sites = ref.watch(companySitesProvider);
    final isMgmt = m?.isManagement ?? false;
    return Scaffold(
      appBar: AppBar(title: Text(_role == 'FOREMAN' ? S.addForeman : S.addWorker)),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _phone,
              autofocus: true,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: S.phone, prefixText: '+998 ', hintText: S.phoneHint),
              validator: (v) => normalizeUzPhone(v ?? '') == null ? S.invalidPhone : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: S.fullName),
              validator: (v) => (v?.trim().length ?? 0) < 2 ? S.required : null,
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _title, decoration: const InputDecoration(labelText: '${S.position} (${S.optional})', hintText: "G'isht teruvchi")),
            if (isMgmt) ...[
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [ButtonSegment(value: 'WORKER', label: Text('Ishchi')), ButtonSegment(value: 'FOREMAN', label: Text('Prorab'))],
                selected: {_role},
                onSelectionChanged: (s) => setState(() => _role = s.first),
              ),
            ],
            const SectionTitle(S.sites),
            AsyncBody(
              value: sites,
              onRetry: () => ref.invalidate(companySitesProvider),
              builder: (list) => list.isEmpty
                  ? const Text(S.noSites)
                  : Card(
                      child: Column(children: [
                        for (final s in list)
                          CheckboxListTile(
                            value: _sites.contains(s.info.id),
                            title: Text(s.info.name),
                            subtitle: Text(s.info.projectName ?? ''),
                            onChanged: (v) => setState(() => v == true ? _sites.add(s.info.id) : _sites.remove(s.info.id)),
                          ),
                      ]),
                    ),
            ),
            if (_role == 'WORKER') ...[
              const SizedBox(height: 8),
              SwitchListTile(value: _resident, onChanged: (v) => setState(() => _resident = v), title: const Text(S.residentWorker), subtitle: const Text(S.residentWorkerDesc)),
            ],
            const SizedBox(height: 20),
            FilledButton(onPressed: _save, child: const Text(S.save)),
          ],
        ),
      ),
    );
  }
}
