import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worker_os/core/api/api_error.dart';
import 'package:worker_os/core/location/location_service.dart';
import 'package:worker_os/core/phone.dart';
import 'package:worker_os/models/models.dart';

void main() {
  group('phone (same rules as backend)', () {
    test('normalises common formats', () {
      expect(normalizeUzPhone('+998 90 123 45 67'), '+998901234567');
      expect(normalizeUzPhone('90 123-45-67'), '+998901234567');
      expect(normalizeUzPhone('998931112233'), '+998931112233');
    });
    test('rejects invalid', () {
      for (final p in ['', '123', '+7 912 123 45 67', '12 345 67 89', 'abc']) {
        expect(normalizeUzPhone(p), isNull, reason: p);
      }
    });
    test('pretty', () => expect(prettyPhone('+998901234567'), '+998 90 123 45 67'));
  });

  group('geofence (same rules as backend)', () {
    test('distance ~111 m per 0.001° latitude', () {
      final d = distanceMeters(41.0, 71.0, 41.001, 71.0);
      expect(d, closeTo(111, 1));
    });
    test('verdicts', () {
      expect(geofenceVerdict(150, 200, 10), GeofenceVerdict.inside);
      expect(geofenceVerdict(250, 200, 80), GeofenceVerdict.uncertain);
      expect(geofenceVerdict(900, 200, 80), GeofenceVerdict.outside);
      expect(geofenceVerdict(900, 200, 100000), GeofenceVerdict.outside);
    });
  });

  group('API errors → specific Uzbek messages', () {
    ApiError fromBody(int status, Map<String, dynamic> body) =>
        ApiError.fromResponse(Response(requestOptions: RequestOptions(path: '/x'), statusCode: status, data: body));

    test('geofence rejection includes distance', () {
      final e = fromBody(400, {'code': 'OUTSIDE_GEOFENCE', 'details': {'distanceMeters': 734}});
      expect(e.message, contains('734'));
      expect(e.message, contains('tashqaridasiz'));
    });
    test('OTP attempts left', () {
      expect(fromBody(400, {'code': 'OTP_INVALID', 'details': {'attemptsLeft': 2}}).message, contains('2'));
    });
    test('foreman worker scope', () {
      expect(fromBody(403, {'code': 'WORKER_NOT_IN_YOUR_SITES'}).message, 'Bu ishchi sizga biriktirilmagan.');
    });
    test('5xx is transient and never shows server internals', () {
      final e = fromBody(500, {'code': 'INTERNAL', 'message': 'TypeError at line 42'});
      expect(e.isTransient, isTrue);
      expect(e.message, isNot(contains('TypeError')));
    });
    test('offline', () {
      final e = ApiError.fromDio(DioException.connectionError(requestOptions: RequestOptions(path: '/x'), reason: 'no route'));
      expect(e.isNetwork, isTrue);
      expect(e.message, 'Internet mavjud emas.');
    });
    test('unknown codes fall back to a generic but friendly message', () {
      expect(fromBody(418, {'code': 'SOMETHING_NEW'}).message, isNotEmpty);
    });
  });

  group('models parse real API payloads', () {
    test('vacancy with Decimal-as-string rate', () {
      final v = Vacancy.fromJson({
        'id': 'v1',
        'title': "G'isht teruvchi",
        'category': 'BRICKLAYER',
        'rateAmount': '250000',
        'currency': 'UZS',
        'paymentPeriod': 'DAILY',
        'workersNeeded': 2,
        'company': {'id': 'c1', 'name': 'Taraqqiyot', 'verificationStatus': 'VERIFIED'},
        'myApplicationStatus': null,
      });
      expect(v.rateAmount, 250000);
      expect(v.company!.verified, isTrue);
    });
    test('me with memberships and roles', () {
      final me = Me.fromJson({
        'id': 'u1',
        'phone': '+998901234567',
        'fullName': 'Aziz',
        'memberships': [
          {'id': 'm1', 'role': 'WORKER', 'company': {'id': 'c1', 'name': 'A'}},
          {'id': 'm2', 'role': 'FOREMAN', 'company': {'id': 'c2', 'name': 'B'}},
        ],
        'notificationPrefs': {'shift': {'push': false, 'inApp': true}},
      });
      expect(me.supervisorMemberships.single.company.name, 'B');
      expect(me.isWorkerSomewhere, isTrue);
      expect(me.notificationPrefs['shift']!['push'], isFalse);
    });
    test('identity keeps verified and self-reported apart', () {
      final i = Identity.fromJson({
        'verified': {'verifiedWorkdays': 127, 'verifiedHours': 1024.5, 'verifiedTasks': 42, 'verifiedEmployers': 3, 'trustLevel': 'WORK_VERIFIED', 'punctualityRate': 0.92},
        'employers': [
          {'companyId': 'c1', 'name': 'A', 'verifiedDays': 100, 'verifiedHours': 800, 'projects': ['P1']},
        ],
        'selfReported': {'primaryTrade': "G'isht teruvchi", 'experienceYears': 2},
      });
      expect(i.verified.verifiedWorkdays, 127);
      expect(i.selfReported!.experienceYears, 2);
    });
    test('tolerates missing / null fields', () {
      final s = Shift.fromJson({'id': 's1', 'startedAt': null});
      expect(s.status, 'OPEN');
      expect(s.flags, isEmpty);
    });
  });
}
