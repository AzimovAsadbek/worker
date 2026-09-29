import 'package:flutter_riverpod/flutter_riverpod.dart';


import '../../core/providers.dart';
import '../../data/repository.dart';
import '../../models/models.dart';

/// The company the supervisor UI is currently operating on.
final activeMembershipProvider = Provider<Membership?>((ref) => ref.watch(sessionProvider.select((s) => s.activeMembership)));
String cidOf(Ref ref) => ref.watch(activeMembershipProvider)?.company.id ?? '';
String cidFrom(WidgetRef ref) => ref.read(activeMembershipProvider)?.company.id ?? '';

final dashboardProvider = FutureProvider.autoDispose.family<Dashboard, String?>((ref, siteId) => ref.read(repoProvider).dashboard(cidOf(ref), siteId: siteId));
final companySitesProvider = FutureProvider.autoDispose<List<CompanySite>>((ref) => ref.read(repoProvider).sites(cidOf(ref)));
final projectsProvider = FutureProvider.autoDispose<List<Project>>((ref) => ref.read(repoProvider).projects(cidOf(ref)));
final reviewQueueProvider = FutureProvider.autoDispose.family<Paged<Shift>, bool>(
  (ref, flaggedOnly) => ref.read(repoProvider).shifts(cidOf(ref), status: const ['CLOSED', 'NEEDS_REVIEW', 'OPEN'], flagged: flaggedOnly),
);
final companyShiftProvider = FutureProvider.autoDispose.family<ShiftDetail, String>((ref, id) => ref.read(repoProvider).shift(cidOf(ref), id));
final membersProvider = FutureProvider.autoDispose.family<Paged<Member>, (String?, String?)>(
  (ref, q) => ref.read(repoProvider).members(cidOf(ref), role: q.$1, search: q.$2),
);
final memberProvider = FutureProvider.autoDispose.family<Member, String>((ref, id) => ref.read(repoProvider).member(cidOf(ref), id));
final workerIdentityProvider = FutureProvider.autoDispose.family<Identity, String>((ref, userId) => ref.read(repoProvider).workerIdentity(cidOf(ref), userId));
final workerShiftsProvider = FutureProvider.autoDispose.family<Paged<Shift>, String>((ref, userId) => ref.read(repoProvider).shifts(cidOf(ref), workerId: userId));
final companyTasksProvider = FutureProvider.autoDispose.family<Paged<WorkTask>, String?>(
  (ref, status) => ref.read(repoProvider).tasks(cidOf(ref), status: status == null ? null : [status]),
);
final companyTaskProvider = FutureProvider.autoDispose.family<WorkTask, String>((ref, id) => ref.read(repoProvider).task(cidOf(ref), id));
final companyVacanciesProvider = FutureProvider.autoDispose<Paged<Vacancy>>((ref) => ref.read(repoProvider).companyVacancies(cidOf(ref)));
final vacancyApplicationsProvider = FutureProvider.autoDispose.family<Paged<Application>, String>((ref, vid) => ref.read(repoProvider).vacancyApplications(cidOf(ref), vid));
final applicationProvider = FutureProvider.autoDispose.family<Application, String>((ref, id) => ref.read(repoProvider).application(cidOf(ref), id));
final disputesProvider = FutureProvider.autoDispose.family<Paged<Dispute>, String?>((ref, status) => ref.read(repoProvider).disputes(cidOf(ref), status: status));
final companyProvider = FutureProvider.autoDispose<Company>((ref) => ref.read(repoProvider).company(cidOf(ref)));
final companyTrustProvider = FutureProvider.autoDispose<CompanyTrust>((ref) => ref.read(repoProvider).trust(cidOf(ref)));
