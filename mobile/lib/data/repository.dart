import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_client.dart';
import '../core/providers.dart';
import '../models/models.dart';

final repoProvider = Provider<Repository>((ref) => Repository(ref.watch(apiProvider)));

String _d(DateTime d) => d.toUtc().toIso8601String();
String _ymd(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Typed access to every endpoint the app uses. Screens never build URLs themselves.
class Repository {
  Repository(this.api);
  final ApiClient api;

  // ───────────── worker ─────────────

  Future<Json> todayRaw() => api.get<Json>('/me/today');

  Future<Paged<Shift>> myShifts({int page = 1}) async =>
      Paged.fromJson(await api.get<Json>('/me/shifts', query: {'page': page, 'limit': 30}), Shift.fromJson);

  Future<ShiftDetail> myShift(String id) async => ShiftDetail.fromJson(await api.get<Json>('/me/shifts/$id'));

  Future<void> openDispute(String shiftId, {required String reason, DateTime? claimedStart, DateTime? claimedEnd}) => api.post<Json>(
        '/me/shifts/$shiftId/disputes',
        body: {'reason': reason, if (claimedStart != null) 'claimedStart': _d(claimedStart), if (claimedEnd != null) 'claimedEnd': _d(claimedEnd)},
      );

  Future<Paged<WorkTask>> myTasks({String? status, int page = 1}) async =>
      Paged.fromJson(await api.get<Json>('/me/tasks', query: {'status': status, 'page': page, 'limit': 50}), WorkTask.fromJson);
  Future<WorkTask> myTask(String id) async => WorkTask.fromJson(await api.get<Json>('/me/tasks/$id'));
  Future<WorkTask> startTask(String id) async => WorkTask.fromJson(await api.post<Json>('/me/tasks/$id/start'));
  Future<WorkTask> submitTask(String id, {double? completedQuantity, String? note}) async => WorkTask.fromJson(
        await api.post<Json>('/me/tasks/$id/submit', body: {'completedQuantity': ?completedQuantity, if (note != null && note.isNotEmpty) 'note': note}),
      );
  Future<void> uploadEvidence(String taskId, {required String path, required String filename, String? comment, double? lat, double? lng}) => api.upload(
        '/me/tasks/$taskId/evidence',
        filePath: path,
        filename: filename,
        fields: {
          if (comment != null && comment.isNotEmpty) 'comment': comment,
          'capturedAt': _d(DateTime.now()),
          if (lat != null) 'latitude': '$lat',
          if (lng != null) 'longitude': '$lng',
        },
      );
  String evidenceUrl(String id) => api.url('/evidence/$id/content');

  Future<Paged<Vacancy>> vacancies({String? category, String? city, String? search, int page = 1}) async => Paged.fromJson(
        await api.get<Json>('/vacancies', query: {'category': category, 'city': city, 'search': search, 'page': page, 'limit': 20}),
        Vacancy.fromJson,
      );
  Future<Vacancy> vacancy(String id) async => Vacancy.fromJson(await api.get<Json>('/vacancies/$id'));
  Future<void> apply(String vacancyId, String? note) =>
      api.post<Json>('/vacancies/$vacancyId/apply', body: {if (note != null && note.isNotEmpty) 'coverNote': note});
  Future<Paged<Application>> myApplications() async => Paged.fromJson(await api.get<Json>('/me/applications', query: {'limit': 50}), Application.fromJson);
  Future<void> withdraw(String applicationId) => api.post<Json>('/me/applications/$applicationId/withdraw');

  Future<Identity> myIdentity() async => Identity.fromJson(await api.get<Json>('/me/identity'));
  Future<void> saveProfile(Json body) => api.put<Json>('/me/worker-profile', body: body);
  Future<void> leaveCompany(String membershipId) => api.post<void>('/me/memberships/$membershipId/leave');
  Future<void> updatePrefs(Map<String, Map<String, bool>> prefs) => api.put<Json>('/me/notification-preferences', body: {'prefs': prefs});
  Future<List<Json>> sessions() async => (await api.get<List<dynamic>>('/auth/sessions')).whereType<Json>().toList();
  Future<void> revokeSession(String id) => api.delete<void>('/auth/sessions/$id');
  Future<void> logoutAll() => api.post<void>('/auth/logout-all');

  Future<(Paged<AppNotification>, int)> notifications({int page = 1}) async {
    final j = await api.get<Json>('/me/notifications', query: {'page': page, 'limit': 30});
    return (Paged.fromJson(j, AppNotification.fromJson), (j['unread'] as num?)?.toInt() ?? 0);
  }

  Future<int> unreadCount() async => ((await api.get<Json>('/me/notifications', query: {'unread': 'true', 'limit': 1}))['unread'] as num?)?.toInt() ?? 0;
  Future<void> markRead(String id) => api.post<void>('/me/notifications/$id/read');
  Future<void> readAll() => api.post<void>('/me/notifications/read-all');

  Future<Json> createCompany(Json body) => api.post<Json>('/companies', body: body);

  // ───────────── company ─────────────

  String _c(String cid) => '/companies/$cid';

  Future<Company> company(String cid) async => Company.fromJson(await api.get<Json>(_c(cid)));
  Future<void> updateCompany(String cid, Json body) => api.patch<Json>(_c(cid), body: body);
  Future<CompanyTrust> trust(String cid) async => CompanyTrust.fromJson(await api.get<Json>('${_c(cid)}/trust'));
  Future<void> requestVerification(String cid, String stir) => api.post<Json>('${_c(cid)}/verification-request', body: {'registrationNumber': stir});

  Future<Dashboard> dashboard(String cid, {String? siteId}) async => Dashboard.fromJson(await api.get<Json>('${_c(cid)}/dashboard', query: {'siteId': siteId}));

  Future<Paged<Member>> members(String cid, {String? role, String? search, String? siteId, int page = 1}) async => Paged.fromJson(
        await api.get<Json>('${_c(cid)}/members', query: {'role': role, 'search': search, 'siteId': siteId, 'page': page, 'limit': 50}),
        Member.fromJson,
      );
  Future<Member> member(String cid, String id) async => Member.fromJson(await api.get<Json>('${_c(cid)}/members/$id'));
  Future<void> addMember(String cid, {required String phone, String? fullName, required String role, String? title, List<String> siteIds = const [], bool isResident = false}) =>
      api.post<Json>('${_c(cid)}/members', body: {
        'phone': phone,
        if (fullName != null && fullName.isNotEmpty) 'fullName': fullName,
        'role': role,
        if (title != null && title.isNotEmpty) 'title': title,
        if (siteIds.isNotEmpty) 'siteIds': siteIds,
        if (role == 'WORKER') 'isResident': isResident,
      });
  Future<void> updateMember(String cid, String id, Json body) => api.patch<Json>('${_c(cid)}/members/$id', body: body);
  Future<void> removeMember(String cid, String id) => api.delete<void>('${_c(cid)}/members/$id');

  Future<List<Project>> projects(String cid) async => (await api.get<List<dynamic>>('${_c(cid)}/projects')).whereType<Json>().map(Project.fromJson).toList();
  Future<Json> createProject(String cid, Json body) => api.post<Json>('${_c(cid)}/projects', body: body);
  Future<List<CompanySite>> sites(String cid) async => (await api.get<List<dynamic>>('${_c(cid)}/sites')).whereType<Json>().map(CompanySite.fromJson).toList();
  Future<Json> createSite(String cid, Json body) => api.post<Json>('${_c(cid)}/sites', body: body);
  Future<void> updateSite(String cid, String siteId, Json body) => api.patch<Json>('${_c(cid)}/sites/$siteId', body: body);
  Future<void> assign(String cid, String siteId, String userId, {bool isResident = false}) =>
      api.post<Json>('${_c(cid)}/sites/$siteId/assignments', body: {'userId': userId, 'isResident': isResident});
  Future<void> unassign(String cid, String siteId, String assignmentId) => api.delete<void>('${_c(cid)}/sites/$siteId/assignments/$assignmentId');
  Future<void> setResident(String cid, String siteId, String assignmentId, bool resident) =>
      api.patch<Json>('${_c(cid)}/sites/$siteId/assignments/$assignmentId', body: {'isResident': resident});

  Future<Paged<Shift>> shifts(String cid, {List<String>? status, String? siteId, String? workerId, bool? flagged, int page = 1}) async => Paged.fromJson(
        await api.get<Json>('${_c(cid)}/shifts', query: {
          'status': status?.join(','),
          'siteId': siteId,
          'workerId': workerId,
          'flagged': flagged == true ? 'true' : null,
          'page': page,
          'limit': 50,
        }),
        Shift.fromJson,
      );
  Future<ShiftDetail> shift(String cid, String id) async => ShiftDetail.fromJson(await api.get<Json>('${_c(cid)}/shifts/$id'));
  Future<void> verifyShift(String cid, String id, {int? breakMinutes, String? note}) => api.post<Json>(
        '${_c(cid)}/shifts/$id/verify',
        body: {'breakMinutes': ?breakMinutes, if (note != null && note.isNotEmpty) 'note': note},
      );
  Future<(List<String>, List<Json>)> bulkVerify(String cid, List<String> ids) async {
    final r = await api.post<Json>('${_c(cid)}/shifts/verify', body: {'shiftIds': ids});
    return ((r['verified'] as List<dynamic>).cast<String>(), (r['skipped'] as List<dynamic>).whereType<Json>().toList());
  }

  Future<void> rejectShift(String cid, String id, String reason) => api.post<Json>('${_c(cid)}/shifts/$id/reject', body: {'reason': reason});
  Future<void> correctShift(String cid, String id, {DateTime? startedAt, DateTime? endedAt, required String reason, bool verify = false, int? breakMinutes}) =>
      api.post<Json>('${_c(cid)}/shifts/$id/correct', body: {
        if (startedAt != null) 'startedAt': _d(startedAt),
        if (endedAt != null) 'endedAt': _d(endedAt),
        'reason': reason,
        'verify': verify,
        'breakMinutes': ?breakMinutes,
      });
  Future<void> manualAttendance(String cid, {required String workerId, required String siteId, required String type, required DateTime occurredAt, required String reason}) =>
      api.post<Json>('${_c(cid)}/attendance/manual', body: {'workerId': workerId, 'siteId': siteId, 'type': type, 'occurredAt': _d(occurredAt), 'reason': reason});

  Future<Paged<WorkTask>> tasks(String cid, {List<String>? status, String? siteId, int page = 1}) async => Paged.fromJson(
        await api.get<Json>('${_c(cid)}/tasks', query: {'status': status?.join(','), 'siteId': siteId, 'page': page, 'limit': 50}),
        WorkTask.fromJson,
      );
  Future<WorkTask> task(String cid, String id) async => WorkTask.fromJson(await api.get<Json>('${_c(cid)}/tasks/$id'));
  Future<void> createTask(String cid, {required String siteId, required String assigneeId, required String title, String? description, double? quantity, String? unit, DateTime? dueDate}) =>
      api.post<Json>('${_c(cid)}/tasks', body: {
        'siteId': siteId,
        'assigneeId': assigneeId,
        'title': title,
        if (description != null && description.isNotEmpty) 'description': description,
        'quantity': ?quantity,
        'unit': ?unit,
        if (dueDate != null) 'dueDate': _ymd(dueDate),
      });
  Future<void> reviewTask(String cid, String id, String decision, {String? comment}) =>
      api.post<Json>('${_c(cid)}/tasks/$id/review', body: {'decision': decision, if (comment != null && comment.isNotEmpty) 'comment': comment});

  Future<Paged<Vacancy>> companyVacancies(String cid, {int page = 1}) async =>
      Paged.fromJson(await api.get<Json>('${_c(cid)}/vacancies', query: {'page': page, 'limit': 50}), Vacancy.fromJson);
  Future<Json> createVacancy(String cid, Json body) => api.post<Json>('${_c(cid)}/vacancies', body: body);
  Future<void> setVacancyStatus(String cid, String id, String status) => api.post<Json>('${_c(cid)}/vacancies/$id/status', body: {'status': status});
  Future<Paged<Application>> vacancyApplications(String cid, String vacancyId) async =>
      Paged.fromJson(await api.get<Json>('${_c(cid)}/vacancies/$vacancyId/applications', query: {'limit': 100}), Application.fromJson);
  Future<Application> application(String cid, String id) async => Application.fromJson(await api.get<Json>('${_c(cid)}/applications/$id'));
  Future<Json> setApplicationStatus(String cid, String id, String status, {String? reason, String? siteId}) => api.post<Json>(
        '${_c(cid)}/applications/$id/status',
        body: {'status': status, if (reason != null && reason.isNotEmpty) 'reason': reason, 'siteId': ?siteId},
      );

  Future<Paged<Dispute>> disputes(String cid, {String? status}) async =>
      Paged.fromJson(await api.get<Json>('${_c(cid)}/disputes', query: {'status': status, 'limit': 50}), Dispute.fromJson);
  Future<void> resolveDispute(String cid, String id, {required bool accept, required String resolution}) =>
      api.post<Json>('${_c(cid)}/disputes/$id/resolve', body: {'accept': accept, 'resolution': resolution});

  Future<Identity> workerIdentity(String cid, String userId) async => Identity.fromJson(await api.get<Json>('${_c(cid)}/workers/$userId/identity'));
}
