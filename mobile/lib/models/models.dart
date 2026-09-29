// Plain immutable models parsed defensively from the API (unknown fields ignored, nulls tolerated).
import '../core/api/api_client.dart' show Json;

DateTime? _dt(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;
DateTime _dtReq(Object? v) => _dt(v) ?? DateTime.fromMillisecondsSinceEpoch(0);
int _int(Object? v, [int d = 0]) => v is num ? v.toInt() : (v is String ? int.tryParse(v) ?? d : d);
double? _dbl(Object? v) => v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);
String? _str(Object? v) => v is String ? v : null;
bool _bool(Object? v) => v == true;
List<String> _strs(Object? v) => v is List ? v.whereType<String>().toList() : const [];
Json _obj(Object? v) => v is Map<String, dynamic> ? v : const {};
List<T> _list<T>(Object? v, T Function(Json) f) => v is List ? v.whereType<Map<String, dynamic>>().map(f).toList() : <T>[];

class Paged<T> {
  Paged({required this.items, required this.page, required this.total, required this.hasMore});
  final List<T> items;
  final int page;
  final int total;
  final bool hasMore;

  factory Paged.fromJson(Json j, T Function(Json) f) =>
      Paged(items: _list(j['items'], f), page: _int(j['page'], 1), total: _int(j['total']), hasMore: _bool(j['hasMore']));
}

class PersonRef {
  PersonRef({required this.id, this.fullName, this.phone});
  final String id;
  final String? fullName;
  final String? phone;
  String get displayName => (fullName?.trim().isNotEmpty ?? false) ? fullName! : (phone ?? '—');
  factory PersonRef.fromJson(Json j) => PersonRef(id: j['id'] as String? ?? '', fullName: _str(j['fullName']), phone: _str(j['phone']));
}

class CompanyRef {
  CompanyRef({required this.id, required this.name, this.verificationStatus});
  final String id;
  final String name;
  final String? verificationStatus;
  bool get verified => verificationStatus == 'VERIFIED';
  factory CompanyRef.fromJson(Json j) => CompanyRef(id: j['id'] as String? ?? '', name: _str(j['name']) ?? '—', verificationStatus: _str(j['verificationStatus']));
}

// ───── me ─────

enum Role { companyAdmin, manager, foreman, worker }

Role roleFrom(String? r) => switch (r) {
      'COMPANY_ADMIN' => Role.companyAdmin,
      'MANAGER' => Role.manager,
      'FOREMAN' => Role.foreman,
      _ => Role.worker,
    };

String roleLabel(Role r) => switch (r) {
      Role.companyAdmin => 'Administrator',
      Role.manager => 'Menejer',
      Role.foreman => 'Prorab',
      Role.worker => 'Ishchi',
    };

class Membership {
  Membership({required this.id, required this.role, required this.company, this.title});
  final String id;
  final Role role;
  final CompanyRef company;
  final String? title;
  bool get isSupervisor => role != Role.worker;
  bool get isManagement => role == Role.companyAdmin || role == Role.manager;
  factory Membership.fromJson(Json j) =>
      Membership(id: j['id'] as String, role: roleFrom(_str(j['role'])), company: CompanyRef.fromJson(_obj(j['company'])), title: _str(j['title']));
}

class WorkerProfile {
  WorkerProfile({this.primaryTrade, this.trades = const [], this.experienceYears, this.bio, this.region, this.city, this.availability});
  final String? primaryTrade;
  final List<String> trades;
  final int? experienceYears;
  final String? bio;
  final String? region;
  final String? city;
  final String? availability;
  factory WorkerProfile.fromJson(Json j) => WorkerProfile(
        primaryTrade: _str(j['primaryTrade']),
        trades: _strs(j['trades']),
        experienceYears: j['selfReportedExperienceYears'] is num ? _int(j['selfReportedExperienceYears']) : (j['experienceYears'] is num ? _int(j['experienceYears']) : null),
        bio: _str(j['bio']),
        region: _str(j['region']),
        city: _str(j['city']),
        availability: _str(j['availability']),
      );
}

class Me {
  Me({required this.id, required this.phone, this.fullName, required this.memberships, this.workerProfile, required this.notificationPrefs});
  final String id;
  final String phone;
  final String? fullName;
  final List<Membership> memberships;
  final WorkerProfile? workerProfile;
  final Map<String, Map<String, bool>> notificationPrefs;
  bool get hasName => fullName?.trim().isNotEmpty ?? false;
  List<Membership> get supervisorMemberships => memberships.where((m) => m.isSupervisor).toList();
  bool get isWorkerSomewhere => memberships.any((m) => m.role == Role.worker);

  factory Me.fromJson(Json j) {
    final prefs = <String, Map<String, bool>>{};
    _obj(j['notificationPrefs']).forEach((k, v) {
      final m = _obj(v);
      prefs[k] = {'push': m['push'] != false, 'inApp': m['inApp'] != false};
    });
    return Me(
      id: j['id'] as String,
      phone: j['phone'] as String,
      fullName: _str(j['fullName']),
      memberships: _list(j['memberships'], Membership.fromJson),
      workerProfile: j['workerProfile'] is Map<String, dynamic> ? WorkerProfile.fromJson(j['workerProfile'] as Json) : null,
      notificationPrefs: prefs,
    );
  }
}

// ───── sites & shifts ─────

class SiteInfo {
  SiteInfo({
    required this.id,
    required this.name,
    this.address,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.shiftStart,
    required this.shiftEnd,
    this.projectName,
    this.status = 'ACTIVE',
  });
  final String id;
  final String name;
  final String? address;
  final double latitude;
  final double longitude;
  final int radiusMeters;
  final String shiftStart;
  final String shiftEnd;
  final String? projectName;
  final String status;
  factory SiteInfo.fromJson(Json j) => SiteInfo(
        id: j['id'] as String,
        name: _str(j['name']) ?? '—',
        address: _str(j['address']),
        latitude: _dbl(j['latitude']) ?? 0,
        longitude: _dbl(j['longitude']) ?? 0,
        radiusMeters: _int(j['radiusMeters'], 200),
        shiftStart: _str(j['shiftStart']) ?? '08:00',
        shiftEnd: _str(j['shiftEnd']) ?? '18:00',
        projectName: _str(j['projectName']) ?? _str(_obj(j['project'])['name']),
        status: _str(j['status']) ?? 'ACTIVE',
      );
  Json toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'radiusMeters': radiusMeters,
        'shiftStart': shiftStart,
        'shiftEnd': shiftEnd,
        'projectName': projectName,
        'status': status,
      };
}

class Shift {
  Shift({
    required this.id,
    required this.siteId,
    required this.status,
    required this.startedAt,
    this.endedAt,
    this.businessDate,
    this.workedMinutes = 0,
    this.verifiedMinutes = 0,
    this.isLate = false,
    this.lateMinutes = 0,
    this.isResident = false,
    this.flags = const [],
    this.siteName,
    this.companyName,
    this.reviewNote,
    this.isStale = false,
    this.worker,
    this.openDisputes = 0,
    this.breakMinutes = 0,
  });
  final String id;
  final String siteId;
  final String status;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String? businessDate;
  final int workedMinutes;
  final int verifiedMinutes;
  final bool isLate;
  final int lateMinutes;
  final bool isResident;
  final List<String> flags;
  final String? siteName;
  final String? companyName;
  final String? reviewNote;
  final bool isStale;
  final PersonRef? worker;
  final int openDisputes;
  final int breakMinutes;

  bool get isOpen => status == 'OPEN';
  bool get isReviewable => status == 'CLOSED' || status == 'NEEDS_REVIEW';

  factory Shift.fromJson(Json j) => Shift(
        id: j['id'] as String,
        siteId: _str(j['siteId']) ?? _str(_obj(j['site'])['id']) ?? '',
        status: _str(j['status']) ?? 'OPEN',
        startedAt: _dtReq(j['startedAt']),
        endedAt: _dt(j['endedAt']),
        businessDate: _str(j['businessDate']),
        workedMinutes: _int(j['workedMinutes']),
        verifiedMinutes: _int(j['verifiedMinutes']),
        isLate: _bool(j['isLate']),
        lateMinutes: _int(j['lateMinutes']),
        isResident: _bool(j['isResident']),
        flags: _strs(j['flags']),
        siteName: _str(j['siteName']) ?? _str(_obj(j['site'])['name']),
        companyName: _str(_obj(j['company'])['name']),
        reviewNote: _str(j['reviewNote']),
        isStale: _bool(j['isStale']),
        worker: j['worker'] is Map<String, dynamic> ? PersonRef.fromJson(j['worker'] as Json) : null,
        openDisputes: _int(j['openDisputes']),
        breakMinutes: _int(j['breakMinutes']),
      );
}

class WorkEventView {
  WorkEventView({
    required this.id,
    required this.type,
    required this.source,
    required this.occurredAt,
    this.receivedAt,
    this.actorName,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.distanceMeters,
    this.insideGeofence,
    this.isMocked,
    this.flags = const [],
    this.reason,
  });
  final String id;
  final String type;
  final String source;
  final DateTime occurredAt;
  final DateTime? receivedAt;
  final String? actorName;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final double? distanceMeters;
  final bool? insideGeofence;
  final bool? isMocked;
  final List<String> flags;
  final String? reason;
  factory WorkEventView.fromJson(Json j) => WorkEventView(
        id: j['id'] as String,
        type: _str(j['type']) ?? '',
        source: _str(j['source']) ?? '',
        occurredAt: _dtReq(j['occurredAt']),
        receivedAt: _dt(j['receivedAt']),
        actorName: _str(_obj(j['actor'])['fullName']),
        latitude: _dbl(j['latitude']),
        longitude: _dbl(j['longitude']),
        accuracy: _dbl(j['accuracyMeters']),
        distanceMeters: _dbl(j['distanceMeters']),
        insideGeofence: j['insideGeofence'] is bool ? j['insideGeofence'] as bool : null,
        isMocked: j['isMocked'] is bool ? j['isMocked'] as bool : null,
        flags: _strs(j['flags']),
        reason: _str(j['reason']),
      );
}

class Dispute {
  Dispute({required this.id, required this.status, required this.reason, this.claimedStart, this.claimedEnd, this.resolution, required this.createdAt, this.shift, this.worker, this.siteName});
  final String id;
  final String status;
  final String reason;
  final DateTime? claimedStart;
  final DateTime? claimedEnd;
  final String? resolution;
  final DateTime createdAt;
  final Shift? shift;
  final PersonRef? worker;
  final String? siteName;
  factory Dispute.fromJson(Json j) {
    final s = _obj(j['shift']);
    return Dispute(
      id: j['id'] as String,
      status: _str(j['status']) ?? 'OPEN',
      reason: _str(j['reason']) ?? '',
      claimedStart: _dt(j['claimedStart']),
      claimedEnd: _dt(j['claimedEnd']),
      resolution: _str(j['resolution']),
      createdAt: _dtReq(j['createdAt']),
      shift: s.isNotEmpty && s['id'] is String ? Shift.fromJson({...s, 'siteId': _str(_obj(s['site'])['id']) ?? ''}) : null,
      worker: s['worker'] is Map<String, dynamic> ? PersonRef.fromJson(s['worker'] as Json) : null,
      siteName: _str(_obj(s['site'])['name']),
    );
  }
}

class ShiftDetail {
  ShiftDetail({required this.shift, required this.events, required this.disputes, this.originalStartAt, this.originalEndAt});
  final Shift shift;
  final List<WorkEventView> events;
  final List<Dispute> disputes;
  final DateTime? originalStartAt;
  final DateTime? originalEndAt;
  factory ShiftDetail.fromJson(Json j) => ShiftDetail(
        shift: Shift.fromJson(j),
        events: _list(j['events'], WorkEventView.fromJson),
        disputes: _list(j['disputes'], Dispute.fromJson),
        originalStartAt: _dt(j['originalStartAt']),
        originalEndAt: _dt(j['originalEndAt']),
      );
}

class TodayAssignment {
  TodayAssignment({required this.assignmentId, required this.isResident, required this.site, required this.company});
  final String assignmentId;
  final bool isResident;
  final SiteInfo site;
  final CompanyRef company;
  factory TodayAssignment.fromJson(Json j) => TodayAssignment(
        assignmentId: _str(j['assignmentId']) ?? '',
        isResident: _bool(j['isResident']),
        site: SiteInfo.fromJson(_obj(j['site'])),
        company: CompanyRef.fromJson(_obj(j['company'])),
      );
  Json toJson() => {'assignmentId': assignmentId, 'isResident': isResident, 'site': site.toJson(), 'company': {'id': company.id, 'name': company.name}};
}

class TodayData {
  TodayData({required this.date, required this.assignments, this.openShift, required this.todayShifts, required this.openTasks, required this.fetchedAt});
  final String date;
  final List<TodayAssignment> assignments;
  final Shift? openShift;
  final List<Shift> todayShifts;
  final int openTasks;
  final DateTime fetchedAt;
  factory TodayData.fromJson(Json j, {DateTime? fetchedAt}) => TodayData(
        date: _str(j['date']) ?? '',
        assignments: _list(j['assignments'], TodayAssignment.fromJson),
        openShift: j['openShift'] is Map<String, dynamic> ? Shift.fromJson(j['openShift'] as Json) : null,
        todayShifts: _list(j['todayShifts'], Shift.fromJson),
        openTasks: _int(j['openTasks']),
        fetchedAt: fetchedAt ?? DateTime.now(),
      );
}

// ───── tasks ─────

class EvidenceRef {
  EvidenceRef({required this.id, required this.kind, required this.mimeType, this.comment, required this.createdAt});
  final String id;
  final String kind;
  final String mimeType;
  final String? comment;
  final DateTime createdAt;
  bool get isImage => mimeType.startsWith('image/');
  factory EvidenceRef.fromJson(Json j) =>
      EvidenceRef(id: j['id'] as String, kind: _str(j['kind']) ?? 'PHOTO', mimeType: _str(j['mimeType']) ?? '', comment: _str(j['comment']), createdAt: _dtReq(j['createdAt']));
}

class TaskApprovalView {
  TaskApprovalView({required this.decision, this.comment, required this.createdAt});
  final String decision;
  final String? comment;
  final DateTime createdAt;
  factory TaskApprovalView.fromJson(Json j) => TaskApprovalView(decision: _str(j['decision']) ?? '', comment: _str(j['comment']), createdAt: _dtReq(j['createdAt']));
}

class WorkTask {
  WorkTask({
    required this.id,
    required this.title,
    this.description,
    this.quantity,
    this.unit,
    this.completedQuantity,
    this.dueDate,
    required this.status,
    this.siteName,
    this.companyName,
    this.assignee,
    this.evidenceCount = 0,
    this.approvals = const [],
    this.evidence = const [],
    this.submissionNote,
    required this.updatedAt,
  });
  final String id;
  final String title;
  final String? description;
  final double? quantity;
  final String? unit;
  final double? completedQuantity;
  final DateTime? dueDate;
  final String status;
  final String? siteName;
  final String? companyName;
  final PersonRef? assignee;
  final int evidenceCount;
  final List<TaskApprovalView> approvals;
  final List<EvidenceRef> evidence;
  final String? submissionNote;
  final DateTime updatedAt;

  bool get isWorkable => status == 'ASSIGNED' || status == 'IN_PROGRESS' || status == 'CHANGES_REQUESTED';

  factory WorkTask.fromJson(Json j) {
    final ev = _list(j['evidence'], EvidenceRef.fromJson);
    return WorkTask(
      id: j['id'] as String,
      title: _str(j['title']) ?? '',
      description: _str(j['description']),
      quantity: _dbl(j['quantity']),
      unit: _str(j['unit']),
      completedQuantity: _dbl(j['completedQuantity']),
      dueDate: _dt(j['dueDate']),
      status: _str(j['status']) ?? 'ASSIGNED',
      siteName: _str(_obj(j['site'])['name']),
      companyName: _str(_obj(j['company'])['name']),
      assignee: j['assignee'] is Map<String, dynamic> ? PersonRef.fromJson(j['assignee'] as Json) : null,
      evidenceCount: j['_count'] is Map<String, dynamic> ? _int(_obj(j['_count'])['evidence']) : ev.length,
      approvals: _list(j['approvals'], TaskApprovalView.fromJson),
      evidence: ev,
      submissionNote: _str(j['submissionNote']),
      updatedAt: _dtReq(j['updatedAt']),
    );
  }
}

// ───── marketplace ─────

class CompanyTrust {
  CompanyTrust({required this.verified, required this.workersManaged, required this.verifiedShifts, required this.completedVacancies, required this.activeProjects, this.memberSince, this.name, this.verificationStatus});
  final bool verified;
  final int workersManaged;
  final int verifiedShifts;
  final int completedVacancies;
  final int activeProjects;
  final DateTime? memberSince;
  final String? name;
  final String? verificationStatus;
  factory CompanyTrust.fromJson(Json j) => CompanyTrust(
        verified: _bool(j['verified']),
        workersManaged: _int(j['workersManaged']),
        verifiedShifts: _int(j['verifiedShifts']),
        completedVacancies: _int(j['completedVacancies']),
        activeProjects: _int(j['activeProjects']),
        memberSince: _dt(j['memberSince']),
        name: _str(j['name']),
        verificationStatus: _str(j['verificationStatus']),
      );
}

class Vacancy {
  Vacancy({
    required this.id,
    required this.title,
    required this.category,
    this.region,
    this.city,
    this.address,
    required this.rateAmount,
    required this.currency,
    required this.paymentPeriod,
    required this.workersNeeded,
    this.startDate,
    this.durationDays,
    this.publishedAt,
    this.company,
    this.myApplicationStatus,
    this.description,
    this.requirements,
    this.status,
    this.trust,
    this.myApplicationId,
    this.canApply = false,
    this.siteId,
    this.siteName,
    this.newApplications = 0,
    this.totalApplications = 0,
    this.acceptedApplications = 0,
  });
  final String id;
  final String title;
  final String category;
  final String? region;
  final String? city;
  final String? address;
  final double rateAmount;
  final String currency;
  final String paymentPeriod;
  final int workersNeeded;
  final DateTime? startDate;
  final int? durationDays;
  final DateTime? publishedAt;
  final CompanyRef? company;
  final String? myApplicationStatus;
  final String? description;
  final String? requirements;
  final String? status;
  final CompanyTrust? trust;
  final String? myApplicationId;
  final bool canApply;
  final String? siteId;
  final String? siteName;
  final int newApplications;
  final int totalApplications;
  final int acceptedApplications;

  factory Vacancy.fromJson(Json j) {
    final apps = _obj(j['applications']);
    final myApp = _obj(j['myApplication']);
    return Vacancy(
      id: j['id'] as String,
      title: _str(j['title']) ?? '',
      category: _str(j['category']) ?? 'OTHER',
      region: _str(j['region']),
      city: _str(j['city']),
      address: _str(j['address']),
      rateAmount: _dbl(j['rateAmount']) ?? 0,
      currency: _str(j['currency']) ?? 'UZS',
      paymentPeriod: _str(j['paymentPeriod']) ?? 'DAILY',
      workersNeeded: _int(j['workersNeeded'], 1),
      startDate: _dt(j['startDate']),
      durationDays: j['durationDays'] is num ? _int(j['durationDays']) : null,
      publishedAt: _dt(j['publishedAt']),
      company: j['company'] is Map<String, dynamic> ? CompanyRef.fromJson(j['company'] as Json) : null,
      myApplicationStatus: _str(j['myApplicationStatus']) ?? _str(myApp['status']),
      myApplicationId: _str(myApp['id']),
      description: _str(j['description']),
      requirements: _str(j['requirements']),
      status: _str(j['status']),
      trust: j['companyTrust'] is Map<String, dynamic> ? CompanyTrust.fromJson(j['companyTrust'] as Json) : null,
      canApply: _bool(j['canApply']),
      siteId: _str(j['siteId']),
      siteName: _str(_obj(j['site'])['name']),
      newApplications: _int(apps['new']),
      totalApplications: _int(apps['total']),
      acceptedApplications: _int(apps['accepted']),
    );
  }
}

class IdentitySummary {
  IdentitySummary({required this.trustLevel, required this.verifiedWorkdays, required this.verifiedHours, required this.verifiedTasks, required this.verifiedEmployers});
  final String trustLevel;
  final int verifiedWorkdays;
  final double verifiedHours;
  final int verifiedTasks;
  final int verifiedEmployers;
  factory IdentitySummary.fromJson(Json j) => IdentitySummary(
        trustLevel: _str(j['trustLevel']) ?? 'SELF_REPORTED',
        verifiedWorkdays: _int(j['verifiedWorkdays']),
        verifiedHours: _dbl(j['verifiedHours']) ?? 0,
        verifiedTasks: _int(j['verifiedTasks']),
        verifiedEmployers: _int(j['verifiedEmployers']),
      );
}

class Application {
  Application({
    required this.id,
    required this.status,
    this.coverNote,
    this.statusReason,
    required this.createdAt,
    this.vacancy,
    this.worker,
    this.workerTrade,
    this.workerExperience,
    this.identity,
    this.fullIdentity,
  });
  final String id;
  final String status;
  final String? coverNote;
  final String? statusReason;
  final DateTime createdAt;
  final Vacancy? vacancy;
  final PersonRef? worker;
  final String? workerTrade;
  final int? workerExperience;
  final IdentitySummary? identity;
  final Identity? fullIdentity;
  factory Application.fromJson(Json j) {
    final w = _obj(j['worker']);
    final profile = _obj(w['workerProfile']);
    final ident = _obj(j['identity']);
    return Application(
      id: j['id'] as String,
      status: _str(j['status']) ?? 'SUBMITTED',
      coverNote: _str(j['coverNote']),
      statusReason: _str(j['statusReason']),
      createdAt: _dtReq(j['createdAt']),
      vacancy: j['vacancy'] is Map<String, dynamic> ? Vacancy.fromJson(j['vacancy'] as Json) : null,
      worker: w.isNotEmpty ? PersonRef.fromJson(w) : null,
      workerTrade: _str(profile['primaryTrade']),
      workerExperience: profile['selfReportedExperienceYears'] is num ? _int(profile['selfReportedExperienceYears']) : null,
      identity: ident.containsKey('trustLevel') ? IdentitySummary.fromJson(ident) : null,
      fullIdentity: ident.containsKey('verified') ? Identity.fromJson(ident) : null,
    );
  }
}

class IdentityStats {
  IdentityStats({
    required this.verifiedWorkdays,
    required this.verifiedHours,
    required this.verifiedTasks,
    required this.verifiedEmployers,
    required this.verifiedProjects,
    this.punctualityRate,
    this.attendanceRate,
    required this.trustLevel,
    this.firstVerifiedDate,
    this.lastVerifiedDate,
  });
  final int verifiedWorkdays;
  final double verifiedHours;
  final int verifiedTasks;
  final int verifiedEmployers;
  final int verifiedProjects;
  final double? punctualityRate;
  final double? attendanceRate;
  final String trustLevel;
  final String? firstVerifiedDate;
  final String? lastVerifiedDate;
  factory IdentityStats.fromJson(Json j) => IdentityStats(
        verifiedWorkdays: _int(j['verifiedWorkdays']),
        verifiedHours: _dbl(j['verifiedHours']) ?? 0,
        verifiedTasks: _int(j['verifiedTasks']),
        verifiedEmployers: _int(j['verifiedEmployers']),
        verifiedProjects: _int(j['verifiedProjects']),
        punctualityRate: _dbl(j['punctualityRate']),
        attendanceRate: _dbl(j['attendanceRate']),
        trustLevel: _str(j['trustLevel']) ?? 'SELF_REPORTED',
        firstVerifiedDate: _str(j['firstVerifiedDate']),
        lastVerifiedDate: _str(j['lastVerifiedDate']),
      );
}

class EmployerRecord {
  EmployerRecord({required this.companyId, required this.name, required this.companyVerified, required this.verifiedDays, required this.verifiedHours, required this.projects});
  final String companyId;
  final String name;
  final bool companyVerified;
  final int verifiedDays;
  final double verifiedHours;
  final List<String> projects;
  factory EmployerRecord.fromJson(Json j) => EmployerRecord(
        companyId: _str(j['companyId']) ?? '',
        name: _str(j['name']) ?? '—',
        companyVerified: _bool(j['companyVerified']),
        verifiedDays: _int(j['verifiedDays']),
        verifiedHours: _dbl(j['verifiedHours']) ?? 0,
        projects: _strs(j['projects']),
      );
}

class Identity {
  Identity({required this.verified, required this.employers, this.selfReported, this.fullName});
  final IdentityStats verified;
  final List<EmployerRecord> employers;
  final WorkerProfile? selfReported;
  final String? fullName;
  factory Identity.fromJson(Json j) => Identity(
        verified: IdentityStats.fromJson(_obj(j['verified'])),
        employers: _list(j['employers'], EmployerRecord.fromJson),
        selfReported: j['selfReported'] is Map<String, dynamic> ? WorkerProfile.fromJson(j['selfReported'] as Json) : null,
        fullName: _str(j['fullName']),
      );
}

class AppNotification {
  AppNotification({required this.id, required this.type, required this.title, required this.body, required this.data, this.readAt, required this.createdAt});
  final String id;
  final String type;
  final String title;
  final String body;
  final Json data;
  final DateTime? readAt;
  final DateTime createdAt;
  bool get isRead => readAt != null;
  factory AppNotification.fromJson(Json j) => AppNotification(
        id: j['id'] as String,
        type: _str(j['type']) ?? '',
        title: _str(j['title']) ?? '',
        body: _str(j['body']) ?? '',
        data: _obj(j['data']),
        readAt: _dt(j['readAt']),
        createdAt: _dtReq(j['createdAt']),
      );
}

// ───── company side ─────

class DashboardWorker {
  DashboardWorker({required this.userId, this.fullName, this.phone, required this.isResident, required this.status, required this.isLate, required this.lateMinutes, this.shift});
  final String userId;
  final String? fullName;
  final String? phone;
  final bool isResident;
  final String status;
  final bool isLate;
  final int lateMinutes;
  final Shift? shift;
  String get displayName => (fullName?.isNotEmpty ?? false) ? fullName! : (phone ?? '—');
  factory DashboardWorker.fromJson(Json j) => DashboardWorker(
        userId: j['userId'] as String,
        fullName: _str(j['fullName']),
        phone: _str(j['phone']),
        isResident: _bool(j['isResident']),
        status: _str(j['status']) ?? 'NOT_YET',
        isLate: _bool(j['isLate']),
        lateMinutes: _int(j['lateMinutes']),
        shift: j['shift'] is Map<String, dynamic> ? Shift.fromJson(j['shift'] as Json) : null,
      );
}

class DashboardTotals {
  DashboardTotals(this.raw);
  final Json raw;
  int operator [](String k) => _int(raw[k]);
}

class DashboardSite {
  DashboardSite({required this.siteId, required this.name, required this.shiftStart, required this.shiftEnd, required this.isWorkDay, required this.totals, required this.workers});
  final String siteId;
  final String name;
  final String shiftStart;
  final String shiftEnd;
  final bool isWorkDay;
  final DashboardTotals totals;
  final List<DashboardWorker> workers;
  factory DashboardSite.fromJson(Json j) {
    final s = _obj(j['site']);
    return DashboardSite(
      siteId: _str(s['id']) ?? '',
      name: _str(s['name']) ?? '—',
      shiftStart: _str(s['shiftStart']) ?? '',
      shiftEnd: _str(s['shiftEnd']) ?? '',
      isWorkDay: j['isWorkDay'] != false,
      totals: DashboardTotals(_obj(j['totals'])),
      workers: _list(j['workers'], DashboardWorker.fromJson),
    );
  }
}

class Dashboard {
  Dashboard({required this.totals, required this.sites, required this.generatedAt});
  final DashboardTotals totals;
  final List<DashboardSite> sites;
  final DateTime generatedAt;
  factory Dashboard.fromJson(Json j) =>
      Dashboard(totals: DashboardTotals(_obj(j['totals'])), sites: _list(j['sites'], DashboardSite.fromJson), generatedAt: _dt(j['generatedAt']) ?? DateTime.now());
}

class MemberAssignment {
  MemberAssignment({required this.id, required this.siteId, required this.siteName, required this.isResident, required this.role});
  final String id;
  final String siteId;
  final String siteName;
  final bool isResident;
  final String role;
  factory MemberAssignment.fromJson(Json j) => MemberAssignment(
        id: j['id'] as String,
        siteId: _str(j['siteId']) ?? '',
        siteName: _str(j['siteName']) ?? _str(_obj(j['site'])['name']) ?? '—',
        isResident: _bool(j['isResident']),
        role: _str(j['role']) ?? 'WORKER',
      );
}

class Member {
  Member({required this.id, required this.userId, required this.role, required this.status, this.title, required this.user, required this.assignments});
  final String id;
  final String userId;
  final Role role;
  final String status;
  final String? title;
  final PersonRef user;
  final List<MemberAssignment> assignments;
  factory Member.fromJson(Json j) => Member(
        id: j['id'] as String,
        userId: _str(j['userId']) ?? '',
        role: roleFrom(_str(j['role'])),
        status: _str(j['status']) ?? 'ACTIVE',
        title: _str(j['title']),
        user: PersonRef.fromJson(_obj(j['user'])),
        assignments: _list(j['assignments'], MemberAssignment.fromJson),
      );
}

class CompanySite {
  CompanySite({required this.info, required this.projectId, required this.workerCount, required this.foremanCount});
  final SiteInfo info;
  final String projectId;
  final int workerCount;
  final int foremanCount;
  factory CompanySite.fromJson(Json j) =>
      CompanySite(info: SiteInfo.fromJson(j), projectId: _str(j['projectId']) ?? '', workerCount: _int(j['workerCount']), foremanCount: _int(j['foremanCount']));
}

class Project {
  Project({required this.id, required this.name, this.description, this.address, required this.status, required this.siteCount});
  final String id;
  final String name;
  final String? description;
  final String? address;
  final String status;
  final int siteCount;
  factory Project.fromJson(Json j) => Project(
        id: j['id'] as String,
        name: _str(j['name']) ?? '',
        description: _str(j['description']),
        address: _str(j['address']),
        status: _str(j['status']) ?? 'ACTIVE',
        siteCount: _int(_obj(j['_count'])['sites']),
      );
}

class Company {
  Company({required this.id, required this.name, this.description, this.phone, this.region, this.city, this.address, required this.verificationStatus, this.registrationNumber, required this.myRole});
  final String id;
  final String name;
  final String? description;
  final String? phone;
  final String? region;
  final String? city;
  final String? address;
  final String verificationStatus;
  final String? registrationNumber;
  final Role myRole;
  factory Company.fromJson(Json j) => Company(
        id: j['id'] as String,
        name: _str(j['name']) ?? '',
        description: _str(j['description']),
        phone: _str(j['phone']),
        region: _str(j['region']),
        city: _str(j['city']),
        address: _str(j['address']),
        verificationStatus: _str(j['verificationStatus']) ?? 'UNVERIFIED',
        registrationNumber: _str(j['registrationNumber']),
        myRole: roleFrom(_str(j['myRole'])),
      );
}
