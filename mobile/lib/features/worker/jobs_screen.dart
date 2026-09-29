import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../data/repository.dart';
import '../../models/models.dart';

class JobsFilter {
  const JobsFilter({this.category, this.search});
  final String? category;
  final String? search;
  @override
  bool operator ==(Object other) => other is JobsFilter && other.category == category && other.search == search;
  @override
  int get hashCode => Object.hash(category, search);
}

final jobsProvider = FutureProvider.autoDispose.family<Paged<Vacancy>, JobsFilter>(
  (ref, f) => ref.read(repoProvider).vacancies(category: f.category, search: f.search),
);

class JobsScreen extends ConsumerStatefulWidget {
  const JobsScreen({super.key});
  @override
  ConsumerState<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends ConsumerState<JobsScreen> {
  String? _category;
  String? _search;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = JobsFilter(category: _category, search: _search);
    final jobs = ref.watch(jobsProvider(filter));
    return Scaffold(
      appBar: AppBar(
        title: const Text(S.jobsTitle),
        actions: [TextButton.icon(onPressed: () => context.push('/applications'), icon: const Icon(Icons.inbox_outlined), label: const Text('Arizalarim'))],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: S.search, isDense: true),
            onChanged: (v) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 400), () => setState(() => _search = v.trim().isEmpty ? null : v.trim()));
            },
          ),
        ),
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(label: const Text(S.all), selected: _category == null, onSelected: (_) => setState(() => _category = null)),
              ),
              for (final e in vacancyCategories.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(label: Text(e.value), selected: _category == e.key, onSelected: (_) => setState(() => _category = e.key)),
                ),
            ],
          ),
        ),
        Expanded(
          child: AsyncBody(
            value: jobs,
            onRetry: () => ref.invalidate(jobsProvider(filter)),
            isEmpty: (p) => p.items.isEmpty,
            empty: const EmptyState(icon: Icons.work_off_outlined, title: S.noJobs, body: S.noJobsBody),
            builder: (page) => RefreshIndicator(
              onRefresh: () => ref.refresh(jobsProvider(filter).future),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                itemCount: page.items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (c, i) => VacancyCard(v: page.items[i], onTap: () => context.push('/vacancy/${page.items[i].id}')),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class VacancyCard extends StatelessWidget {
  const VacancyCard({super.key, required this.v, required this.onTap});
  final Vacancy v;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(v.title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text('${fmtMoney(v.rateAmount, v.currency)} ${paymentPeriodLabel(v.paymentPeriod)}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.start)),
              const SizedBox(height: 6),
              Row(children: [
                Flexible(child: Text(v.company?.name ?? '', overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted))),
                if (v.company?.verified ?? false) ...[const SizedBox(width: 4), const Icon(Icons.verified, size: 16, color: AppColors.verified)],
              ]),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                Pill(categoryLabel(v.category), color: AppColors.primary),
                if (v.city != null) Pill(v.city!, icon: Icons.place_outlined),
                if (v.myApplicationStatus != null) Pill(applicationStatusLabel(v.myApplicationStatus!), color: AppColors.warning),
              ]),
            ]),
          ),
        ),
      );
}
