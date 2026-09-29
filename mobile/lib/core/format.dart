import 'package:intl/intl.dart';

final _time = DateFormat('HH:mm');
final _date = DateFormat('d MMMM', 'uz');
final _dateY = DateFormat('d MMMM y', 'uz');
final _num = NumberFormat.decimalPattern('uz');

String fmtTime(DateTime? d) => d == null ? '—' : _time.format(d.toLocal());
String fmtDate(DateTime? d) => d == null ? '—' : (d.year == DateTime.now().year ? _date : _dateY).format(d.toLocal());
String fmtDateTime(DateTime? d) => d == null ? '—' : '${fmtDate(d)}, ${fmtTime(d)}';

/// "2026-09-29" → "29 sentabr"
String fmtYmd(String? ymd) {
  if (ymd == null || ymd.length < 10) return '—';
  final d = DateTime.tryParse(ymd.substring(0, 10));
  return d == null ? ymd : fmtDate(d);
}

String fmtMinutes(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '$m daq';
  return m == 0 ? '$h soat' : '$h soat $m daq';
}

String fmtHours(double h) => h == h.roundToDouble() ? h.toInt().toString() : h.toStringAsFixed(1);

String fmtMoney(double amount, [String currency = 'UZS']) => "${_num.format(amount.round())} ${currency == 'UZS' ? "so'm" : currency}";

String fmtPercent(double? r) => r == null ? '—' : '${(r * 100).round()}%';

String paymentPeriodLabel(String p) => switch (p) {
      'HOURLY' => 'soatiga',
      'DAILY' => 'kuniga',
      'WEEKLY' => 'haftasiga',
      'MONTHLY' => 'oyiga',
      'PER_TASK' => 'ish uchun',
      _ => p,
    };

const vacancyCategories = <String, String>{
  'GENERAL_LABOR': 'Oddiy ishchi',
  'BRICKLAYER': "G'isht teruvchi",
  'CONCRETE': 'Betonchi',
  'REBAR': 'Armaturachi',
  'CARPENTER': 'Duradgor',
  'WELDER': 'Payvandchi',
  'ELECTRICIAN': 'Elektrik',
  'PLUMBER': 'Santexnik',
  'PLASTERER': 'Suvoqchi',
  'PAINTER': "Bo'yoqchi",
  'TILER': 'Kafelchi',
  'ROOFER': 'Tom yopuvchi',
  'MACHINE_OPERATOR': 'Texnika operatori',
  'DRIVER': 'Haydovchi',
  'CRANE_OPERATOR': 'Kran operatori',
  'OTHER': 'Boshqa',
};
String categoryLabel(String c) => vacancyCategories[c] ?? c;

const taskUnits = <String, String>{'m2': 'm²', 'm3': 'm³', 'm': 'm', 'pcs': 'dona', 'kg': 'kg', 't': 't', 'hours': 'soat', 'other': 'boshqa'};
String unitLabel(String? u) => u == null ? '' : (taskUnits[u] ?? u);
String qty(double? q, String? unit) => q == null ? '' : '${q == q.roundToDouble() ? q.toInt() : q} ${unitLabel(unit)}'.trim();

String shiftStatusLabel(String s) => switch (s) {
      'OPEN' => 'Ishlayapti',
      'CLOSED' => 'Tasdiqlash kutilmoqda',
      'NEEDS_REVIEW' => 'Tekshiruv kerak',
      'VERIFIED' => 'Tasdiqlangan',
      'REJECTED' => 'Rad etilgan',
      _ => s,
    };

String taskStatusLabel(String s) => switch (s) {
      'ASSIGNED' => 'Yangi',
      'IN_PROGRESS' => 'Bajarilmoqda',
      'SUBMITTED' => 'Tekshiruvda',
      'CHANGES_REQUESTED' => 'Qayta ishlash kerak',
      'APPROVED' => 'Tasdiqlangan',
      'REJECTED' => 'Rad etilgan',
      'CANCELLED' => 'Bekor qilingan',
      _ => s,
    };

String applicationStatusLabel(String s) => switch (s) {
      'SUBMITTED' => 'Yuborilgan',
      'SHORTLISTED' => 'Saralangan',
      'ACCEPTED' => 'Qabul qilingan',
      'REJECTED' => 'Rad etilgan',
      'WITHDRAWN' => 'Qaytarib olingan',
      _ => s,
    };

String vacancyStatusLabel(String? s) => switch (s) {
      'DRAFT' => 'Qoralama',
      'OPEN' => 'Faol',
      'PAUSED' => "To'xtatilgan",
      'CLOSED' => 'Yopilgan',
      'FILLED' => "To'ldi",
      _ => s ?? '',
    };

String trustLevelLabel(String t) => switch (t) {
      'SELF_REPORTED' => "O'zi kiritgan",
      'EMPLOYER_VERIFIED' => 'Ish beruvchi tasdiqlagan',
      'WORK_VERIFIED' => 'Ishi tasdiqlangan',
      'PERFORMANCE_VERIFIED' => 'Natijasi tasdiqlangan',
      _ => t,
    };

String flagLabel(String f) => switch (f) {
      'OUTSIDE_GEOFENCE' => 'Hududdan tashqarida',
      'GEOFENCE_UNCERTAIN' => 'GPS noaniq (chegarada)',
      'LOW_ACCURACY' => 'GPS aniqligi past',
      'MOCK_LOCATION' => 'Soxta GPS belgisi',
      'IMPOSSIBLE_TRAVEL' => "Imkonsiz ko'chish",
      'SHARED_DEVICE' => 'Umumiy telefon',
      'LATE_SYNC' => 'Kechikib yuborilgan (offlayn)',
      'LONG_SHIFT' => 'Juda uzun smena',
      'MISSED_CHECKOUT' => 'Yakunlanmagan',
      'MANUAL_ENTRY' => "Qo'lda kiritilgan",
      'NO_LOCATION' => "Joylashuv yo'q",
      'CORRECTED' => "To'g'rilangan",
      _ => f,
    };

String eventTypeLabel(String t) => switch (t) {
      'WORK_STARTED' => 'Ish boshlandi',
      'WORK_ENDED' => 'Ish yakunlandi',
      'SHIFT_AUTO_CLOSED' => 'Avtomatik yopildi (yakunlanmagan)',
      'SHIFT_VERIFIED' => 'Tasdiqlandi',
      'SHIFT_REJECTED' => 'Rad etildi',
      'SHIFT_CORRECTED' => "Vaqt to'g'rilandi",
      'DISPUTE_OPENED' => "E'tiroz bildirildi",
      'DISPUTE_RESOLVED' => "E'tiroz ko'rib chiqildi",
      _ => t,
    };
