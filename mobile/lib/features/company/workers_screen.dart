import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/phone.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../models/models.dart';
import 'company_providers.dart';

class WorkersScreen extends ConsumerStatefulWidget {
  const WorkersScreen({super.key});
  @override
  ConsumerState<WorkersScreen> createState() => _WorkersScreenState();
}

class _WorkersScreenState extends ConsumerState<WorkersScreen> {
  String _role = 'WORKER';
  String? _search;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = ref.watch(activeMembershipProvider);
    final isMgmt = m?.isManagement ?? false;
    final key = (isMgmt ? _role : 'WORKER', _search);
    final members = ref.watch(membersProvider(key));
    return Scaffold(
      appBar: AppBar(title: const Text(S.tabWorkers)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/company/workers/add');
          ref.invalidate(membersProvider);
        },
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text(S.addWorker),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Ism yoki telefon', isDense: true),
            onChanged: (v) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 400), () => setState(() => _search = v.trim().isEmpty ? null : v.trim()));
            },
          ),
        ),
        if (isMgmt)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'WORKER', label: Text('Ishchilar')),
                ButtonSegment(value: 'FOREMAN', label: Text('Prorablar')),
                ButtonSegment(value: 'COMPANY_ADMIN', label: Text('Admin')),
              ],
              selected: {_role},
              onSelectionChanged: (s) => setState(() => _role = s.first),
            ),
          ),
        Expanded(
          child: AsyncBody(
            value: members,
            onRetry: () => ref.invalidate(membersProvider(key)),
            isEmpty: (p) => p.items.isEmpty,
            empty: EmptyState(
              icon: Icons.groups_outlined,
              title: S.noWorkers,
              body: S.addFirstWorker,
              action: S.addWorker,
              onAction: () => context.push('/company/workers/add'),
            ),
            builder: (p) => RefreshIndicator(
              onRefresh: () => ref.refresh(membersProvider(key).future),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                itemCount: p.items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (c, i) => _MemberTile(member: p.items[i]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member});
  final Member member;
  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: CircleAvatar(child: Text(member.user.displayName.characters.first.toUpperCase())),
          title: Text(member.user.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text([
            if (member.user.phone != null) prettyPhone(member.user.phone!),
            ?member.title,
            if (member.assignments.isNotEmpty) member.assignments.map((a) => a.siteName).join(', '),
          ].join('\n')),
          isThreeLine: member.assignments.isNotEmpty,
          trailing: member.status == 'SUSPENDED' ? const Pill("To'xtatilgan", color: AppColors.danger) : const Icon(Icons.chevron_right),
          onTap: () => context.push('/company/workers/${member.id}'),
        ),
      );
}
