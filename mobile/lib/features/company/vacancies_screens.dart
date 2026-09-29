import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/l10n/strings.dart';
import '../../core/phone.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../data/repository.dart';
import '../../models/models.dart';
import '../worker/profile_screen.dart';
import 'company_providers.dart';

class CompanyVacanciesScreen extends ConsumerWidget {
  const CompanyVacanciesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(companyVacanciesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(S.vacancies)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/company/more/vacancies/new');
          ref.invalidate(companyVacanciesProvider);
        },
        icon: const Icon(Icons.add),
        label: const Text(S.createVacancy),
      ),
      body: AsyncBody(
        value: list,
        onRetry: () => ref.invalidate(companyVacanciesProvider),
        isEmpty: (p) => p.items.isEmpty,
        empty: EmptyState(icon: Icons.campaign_outlined, title: S.noVacancies, body: S.createFirstVacancy, action: S.createVacancy, onAction: () => context.push('/company/more/vacancies/new')),
        builder: (p) => RefreshIndicator(
          onRefresh: () => ref.refresh(companyVacanciesProvider.future),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
            itemCount: p.items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (c, i) {
              final v = p.items[i];
              return RecordTile(
                title: v.title,
                lines: ['${fmtMoney(v.rateAmount)} ${paymentPeriodLabel(v.paymentPeriod)}', '${v.acceptedApplications}/${v.workersNeeded} qabul qilindi'],
                badges: [
                  Pill(vacancyStatusLabel(v.status), color: v.status == 'OPEN' ? AppColors.start : AppColors.muted),
                  if (v.newApplications > 0) Pill('${v.newApplications} yangi ariza', color: AppColors.primary, icon: Icons.fiber_new_outlined),
                ],
                onTap: () async {
                  await context.push('/company/vacancy/${v.id}');
                  ref.invalidate(companyVacanciesProvider);
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class VacancyApplicationsScreen extends ConsumerWidget {
  const VacancyApplicationsScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vacancies = ref.watch(companyVacanciesProvider);
    final apps = ref.watch(vacancyApplicationsProvider(id));
    final v = vacancies.value?.items.where((x) => x.id == id).firstOrNull;
    Future<void> setStatus(String status) async {
      await runAction(context, () => ref.read(repoProvider).setVacancyStatus(cidFrom(ref), id, status), success: 'Saqlandi');
      ref.invalidate(companyVacanciesProvider);
    }

    return Scaffold(
      appBar: AppBar(title: Text(v?.title ?? S.applications)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (v != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text('${fmtMoney(v.rateAmount)} ${paymentPeriodLabel(v.paymentPeriod)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17))),
                    Pill(vacancyStatusLabel(v.status), color: v.status == 'OPEN' ? AppColors.start : AppColors.muted),
                  ]),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, children: [
                    if (v.status == 'DRAFT' || v.status == 'PAUSED') FilledButton.tonal(onPressed: () => setStatus('OPEN'), child: const Text(S.publish)),
                    if (v.status == 'OPEN') OutlinedButton(onPressed: () => setStatus('PAUSED'), child: const Text(S.pause)),
                    if (v.status != 'CLOSED' && v.status != 'FILLED') OutlinedButton(onPressed: () => setStatus('CLOSED'), child: const Text(S.closeVacancy)),
                  ]),
                ]),
              ),
            ),
          const SectionTitle(S.applications),
          AsyncBody(
            value: apps,
            onRetry: () => ref.invalidate(vacancyApplicationsProvider(id)),
            isEmpty: (p) => p.items.isEmpty,
            empty: const Padding(padding: EdgeInsets.all(24), child: Text(S.noApplicants, textAlign: TextAlign.center)),
            builder: (p) => Column(children: [
              for (final a in p.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: RecordTile(
                    title: a.worker?.displayName ?? '—',
                    lines: [
                      if (a.workerTrade != null) '${a.workerTrade}${a.workerExperience != null ? ' · ${a.workerExperience} yil (o\'zi aytgan)' : ''}',
                    ],
                    badges: [
                      Pill(applicationStatusLabel(a.status), color: a.status == 'ACCEPTED' ? AppColors.verified : (a.status == 'REJECTED' ? AppColors.danger : AppColors.primary)),
                      if (a.identity != null) Pill('${a.identity!.verifiedWorkdays} kun · ${fmtHours(a.identity!.verifiedHours)} soat', color: AppColors.verified, icon: Icons.verified_outlined),
                      if (a.identity != null) Pill(trustLevelLabel(a.identity!.trustLevel), color: AppColors.muted),
                    ],
                    onTap: () async {
                      await context.push('/company/application/${a.id}');
                      ref.invalidate(vacancyApplicationsProvider(id));
                      ref.invalidate(companyVacanciesProvider);
                    },
                  ),
                ),
            ]),
          ),
        ],
      ),
    );
  }
}

class ApplicationDetailScreen extends ConsumerWidget {
  const ApplicationDetailScreen({super.key, required this.id});
  final String id;

  Future<void> _set(BuildContext context, WidgetRef ref, String status) async {
    String? reason;
    if (status == 'REJECTED') {
      reason = await promptText(context, title: S.reject, hint: 'Sabab (ishchiga ko\'rinadi)', required: false);
      if (reason == null) return;
    } else if (status == 'ACCEPTED') {
      if (!await confirmDialog(context, title: 'Ishga olasizmi?', body: "Ishchi kompaniyangizga qo'shiladi va vakansiya obyektiga biriktiriladi.")) return;
    }
    if (!context.mounted) return;
    await runAction(context, () => ref.read(repoProvider).setApplicationStatus(cidFrom(ref), id, status, reason: reason), success: 'Saqlandi');
    ref.invalidate(applicationProvider(id));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(applicationProvider(id));
    return Scaffold(
      appBar: AppBar(title: const Text('Ariza')),
      body: AsyncBody(
        value: app,
        onRetry: () => ref.invalidate(applicationProvider(id)),
        builder: (a) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(a.worker?.displayName ?? '—', style: Theme.of(context).textTheme.titleLarge),
                subtitle: Text([if (a.worker?.phone != null) prettyPhone(a.worker!.phone!), a.vacancy?.title].whereType<String>().join('\n')),
                trailing: Pill(applicationStatusLabel(a.status)),
              ),
            ),
            if (a.coverNote != null) ...[const SectionTitle('Xabar'), Text(a.coverNote!, style: const TextStyle(fontSize: 16))],
            if (a.fullIdentity != null) IdentityView(identity: a.fullIdentity!),
            const SizedBox(height: 20),
            if (a.status == 'SUBMITTED' || a.status == 'SHORTLISTED') ...[
              FilledButton.icon(onPressed: () => _set(context, ref, 'ACCEPTED'), icon: const Icon(Icons.how_to_reg), label: const Text(S.accept)),
              const SizedBox(height: 8),
              if (a.status == 'SUBMITTED') OutlinedButton(onPressed: () => _set(context, ref, 'SHORTLISTED'), child: const Text(S.shortlist)),
              const SizedBox(height: 8),
              OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger), onPressed: () => _set(context, ref, 'REJECTED'), child: const Text(S.reject)),
            ],
          ],
        ),
      ),
    );
  }
}

class CreateVacancyScreen extends ConsumerStatefulWidget {
  const CreateVacancyScreen({super.key});
  @override
  ConsumerState<CreateVacancyScreen> createState() => _CreateVacancyScreenState();
}

class _CreateVacancyScreenState extends ConsumerState<CreateVacancyScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _req = TextEditingController();
  final _rate = TextEditingController();
  final _count = TextEditingController(text: '1');
  final _city = TextEditingController();
  final _days = TextEditingController();
  String _category = 'GENERAL_LABOR';
  String _period = 'DAILY';
  String? _siteId;
  DateTime? _start;
  bool _publish = true;

  @override
  void dispose() {
    for (final c in [_title, _desc, _req, _rate, _count, _city, _days]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final ok = await runAction(context, () async {
      await ref.read(repoProvider).createVacancy(cidFrom(ref), {
        'title': _title.text.trim(),
        'description': _desc.text.trim(),
        'category': _category,
        'rateAmount': double.parse(_rate.text.replaceAll(RegExp(r'\s'), '')),
        'paymentPeriod': _period,
        'workersNeeded': int.parse(_count.text),
        if (_city.text.trim().isNotEmpty) 'city': _city.text.trim(),
        if (_req.text.trim().isNotEmpty) 'requirements': _req.text.trim(),
        if (_days.text.trim().isNotEmpty) 'durationDays': int.parse(_days.text),
        if (_start != null) 'startDate': '${_start!.year}-${_start!.month.toString().padLeft(2, '0')}-${_start!.day.toString().padLeft(2, '0')}',
        'siteId': ?_siteId,
        'publish': _publish,
      });
      return true;
    }, success: 'Vakansiya saqlandi');
    if (ok == true && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final sites = ref.watch(companySitesProvider);
    final isForeman = ref.watch(activeMembershipProvider)?.role == Role.foreman;
    return Scaffold(
      appBar: AppBar(title: const Text(S.createVacancy)),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(controller: _title, decoration: const InputDecoration(labelText: 'Sarlavha', hintText: "G'isht teruvchi kerak"), validator: (v) => (v?.trim().length ?? 0) < 3 ? S.required : null),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: S.category),
              items: [for (final e in vacancyCategories.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: _rate,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: "${S.rate} (so'm)"),
                  validator: (v) => (int.tryParse(v ?? '') ?? 0) <= 0 ? S.required : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  initialValue: _period,
                  decoration: const InputDecoration(labelText: S.paymentPeriod),
                  items: [for (final p in ['HOURLY', 'DAILY', 'WEEKLY', 'MONTHLY', 'PER_TASK']) DropdownMenuItem(value: p, child: Text(paymentPeriodLabel(p)))],
                  onChanged: (v) => setState(() => _period = v ?? _period),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _count,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: S.workersNeeded),
                  validator: (v) => (int.tryParse(v ?? '') ?? 0) < 1 ? S.required : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: TextFormField(controller: _days, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(labelText: '${S.duration} (kun)'))),
            ]),
            const SizedBox(height: 12),
            AsyncBody(
              value: sites,
              onRetry: () => ref.invalidate(companySitesProvider),
              builder: (list) => DropdownButtonFormField<String>(
                initialValue: _siteId,
                decoration: InputDecoration(labelText: isForeman ? 'Obyekt' : 'Obyekt (${S.optional})'),
                items: [for (final s in list) DropdownMenuItem(value: s.info.id, child: Text(s.info.name))],
                onChanged: (v) => setState(() => _siteId = v),
                validator: (v) => isForeman && v == null ? S.required : null,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _city, decoration: const InputDecoration(labelText: S.city)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.event_outlined),
              label: Text(_start == null ? '${S.startDate} (${S.optional})' : '${S.startDate}: ${fmtDate(_start)}'),
              onPressed: () async {
                final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                if (d != null) setState(() => _start = d);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _desc, maxLines: 4, decoration: const InputDecoration(labelText: S.description), validator: (v) => (v?.trim().length ?? 0) < 10 ? 'Kamida 10 belgi' : null),
            const SizedBox(height: 12),
            TextFormField(controller: _req, maxLines: 2, decoration: const InputDecoration(labelText: '${S.requirements} (${S.optional})')),
            SwitchListTile(contentPadding: EdgeInsets.zero, value: _publish, onChanged: (v) => setState(() => _publish = v), title: const Text("Darhol e'lon qilish")),
            const SizedBox(height: 12),
            FilledButton(onPressed: _save, child: const Text(S.save)),
          ],
        ),
      ),
    );
  }
}
