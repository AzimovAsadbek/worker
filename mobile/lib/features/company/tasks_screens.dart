import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../data/repository.dart';
import '../../models/models.dart';
import '../common/evidence_grid.dart';
import 'company_providers.dart';

class CompanyTasksScreen extends ConsumerStatefulWidget {
  const CompanyTasksScreen({super.key});
  @override
  ConsumerState<CompanyTasksScreen> createState() => _CompanyTasksScreenState();
}

class _CompanyTasksScreenState extends ConsumerState<CompanyTasksScreen> {
  String? _status = 'SUBMITTED';
  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(companyTasksProvider(_status));
    const filters = {'SUBMITTED': 'Tekshiruvda', 'IN_PROGRESS': 'Bajarilmoqda', 'ASSIGNED': 'Yangi', 'APPROVED': 'Tasdiqlangan'};
    return Scaffold(
      appBar: AppBar(title: const Text(S.tasks)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/company/more/tasks/new');
          ref.invalidate(companyTasksProvider);
        },
        icon: const Icon(Icons.add_task),
        label: const Text(S.createTask),
      ),
      body: Column(children: [
        SizedBox(
          height: 52,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), children: [
            Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: const Text(S.all), selected: _status == null, onSelected: (_) => setState(() => _status = null))),
            for (final e in filters.entries)
              Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(e.value), selected: _status == e.key, onSelected: (_) => setState(() => _status = e.key))),
          ]),
        ),
        Expanded(
          child: AsyncBody(
            value: tasks,
            onRetry: () => ref.invalidate(companyTasksProvider(_status)),
            isEmpty: (p) => p.items.isEmpty,
            empty: const EmptyState(icon: Icons.assignment_outlined, title: S.noTasks),
            builder: (p) => RefreshIndicator(
              onRefresh: () => ref.refresh(companyTasksProvider(_status).future),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
                itemCount: p.items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (c, i) {
                  final t = p.items[i];
                  return Card(
                    child: ListTile(
                      title: Text(t.title),
                      subtitle: Text([t.assignee?.displayName, qty(t.quantity, t.unit), t.siteName, if (t.evidenceCount > 0) '${t.evidenceCount} rasm'].where((x) => x != null && x.isNotEmpty).join(' · ')),
                      trailing: Pill(taskStatusLabel(t.status), color: taskStatusColor(t.status)),
                      onTap: () async {
                        await context.push('/company/task/${t.id}');
                        ref.invalidate(companyTasksProvider);
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class TaskReviewScreen extends ConsumerWidget {
  const TaskReviewScreen({super.key, required this.id});
  final String id;

  Future<void> _review(BuildContext context, WidgetRef ref, String decision) async {
    String? comment;
    if (decision != 'APPROVED') {
      comment = await promptText(context, title: decision == 'REJECTED' ? S.reject : S.requestChanges, hint: S.comment);
      if (comment == null) return;
    }
    if (!context.mounted) return;
    await runAction(context, () => ref.read(repoProvider).reviewTask(cidFrom(ref), id, decision, comment: comment), success: 'Saqlandi');
    ref.invalidate(companyTaskProvider(id));
    ref.invalidate(dashboardProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = ref.watch(companyTaskProvider(id));
    return Scaffold(
      appBar: AppBar(title: const Text('Vazifa')),
      body: AsyncBody(
        value: task,
        onRetry: () => ref.invalidate(companyTaskProvider(id)),
        builder: (t) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(children: [
              Expanded(child: Text(t.title, style: Theme.of(context).textTheme.titleLarge)),
              Pill(taskStatusLabel(t.status), color: taskStatusColor(t.status)),
            ]),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(children: [
                  InfoRow('Ishchi', t.assignee?.displayName ?? '—'),
                  if (t.siteName != null) InfoRow('Obyekt', t.siteName!),
                  if (t.quantity != null) InfoRow(S.quantity, qty(t.quantity, t.unit)),
                  if (t.completedQuantity != null) InfoRow(S.completedQuantity, qty(t.completedQuantity, t.unit)),
                  if (t.dueDate != null) InfoRow(S.dueDate, fmtDate(t.dueDate)),
                  if (t.submissionNote != null) InfoRow('Ishchi izohi', t.submissionNote!),
                ]),
              ),
            ),
            if (t.description != null) ...[const SectionTitle(S.description), Text(t.description!)],
            const SectionTitle(S.evidence),
            EvidenceGrid(evidence: t.evidence),
            if (t.approvals.isNotEmpty) ...[
              const SectionTitle('Tarix'),
              for (final a in t.approvals) ListTile(dense: true, title: Text(a.decision), subtitle: Text([a.comment, fmtDateTime(a.createdAt)].whereType<String>().join(' · '))),
            ],
            if (t.status == 'SUBMITTED') ...[
              const SizedBox(height: 20),
              FilledButton.icon(onPressed: () => _review(context, ref, 'APPROVED'), icon: const Icon(Icons.verified_outlined), label: const Text(S.approve)),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: () => _review(context, ref, 'CHANGES_REQUESTED'), child: const Text(S.requestChanges)),
              const SizedBox(height: 8),
              OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger), onPressed: () => _review(context, ref, 'REJECTED'), child: const Text(S.reject)),
            ],
          ],
        ),
      ),
    );
  }
}

class CreateTaskScreen extends ConsumerStatefulWidget {
  const CreateTaskScreen({super.key});
  @override
  ConsumerState<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends ConsumerState<CreateTaskScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _qty = TextEditingController();
  String? _siteId;
  String? _workerId;
  String _unit = 'm2';
  DateTime? _due;

  @override
  void dispose() {
    for (final c in [_title, _desc, _qty]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final ok = await runAction(context, () async {
      await ref.read(repoProvider).createTask(
            cidFrom(ref),
            siteId: _siteId!,
            assigneeId: _workerId!,
            title: _title.text.trim(),
            description: _desc.text.trim(),
            quantity: double.tryParse(_qty.text.replaceAll(',', '.')),
            unit: _qty.text.trim().isEmpty ? null : _unit,
            dueDate: _due,
          );
      return true;
    }, success: 'Vazifa berildi');
    if (ok == true && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final sites = ref.watch(companySitesProvider);
    final workers = _siteId == null ? null : ref.watch(_siteWorkersProvider(_siteId!));
    return Scaffold(
      appBar: AppBar(title: const Text(S.createTask)),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AsyncBody(
              value: sites,
              onRetry: () => ref.invalidate(companySitesProvider),
              builder: (list) => DropdownButtonFormField<String>(
                initialValue: _siteId,
                decoration: const InputDecoration(labelText: 'Obyekt'),
                items: [for (final s in list) DropdownMenuItem(value: s.info.id, child: Text(s.info.name))],
                onChanged: (v) => setState(() {
                  _siteId = v;
                  _workerId = null;
                }),
                validator: (v) => v == null ? S.required : null,
              ),
            ),
            const SizedBox(height: 12),
            if (workers != null)
              AsyncBody(
                value: workers,
                onRetry: () => ref.invalidate(_siteWorkersProvider(_siteId!)),
                builder: (list) => DropdownButtonFormField<String>(
                  initialValue: _workerId,
                  decoration: const InputDecoration(labelText: 'Ishchi'),
                  items: [for (final m in list) DropdownMenuItem(value: m.userId, child: Text(m.user.displayName))],
                  onChanged: (v) => setState(() => _workerId = v),
                  validator: (v) => v == null ? S.required : null,
                ),
              ),
            const SizedBox(height: 12),
            TextFormField(controller: _title, decoration: const InputDecoration(labelText: S.taskTitle, hintText: "G'isht terish — 3-qavat"), validator: (v) => (v?.trim().length ?? 0) < 2 ? S.required : null),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(flex: 2, child: TextFormField(controller: _qty, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: '${S.quantity} (${S.optional})'))),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _unit,
                  decoration: const InputDecoration(labelText: S.unit),
                  items: [for (final e in taskUnits.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                  onChanged: (v) => setState(() => _unit = v ?? 'm2'),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.event_outlined),
              label: Text(_due == null ? '${S.dueDate} (${S.optional})' : '${S.dueDate}: ${fmtDate(_due)}'),
              onPressed: () async {
                final d = await showDatePicker(context: context, initialDate: DateTime.now().add(const Duration(days: 1)), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                if (d != null) setState(() => _due = d);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _desc, maxLines: 3, decoration: const InputDecoration(labelText: '${S.description} (${S.optional})')),
            const SizedBox(height: 20),
            FilledButton(onPressed: _save, child: const Text(S.createTask)),
          ],
        ),
      ),
    );
  }
}

final _siteWorkersProvider = FutureProvider.autoDispose.family<List<Member>, String>((ref, siteId) async {
  final page = await ref.read(repoProvider).members(cidOf(ref), role: 'WORKER', siteId: siteId);
  return page.items;
});
