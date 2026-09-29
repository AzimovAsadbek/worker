import 'dart:async';
import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';

import '../l10n/strings.dart';

sealed class LocationResult {
  const LocationResult();
}

class LocationOk extends LocationResult {
  const LocationOk(this.latitude, this.longitude, this.accuracy, this.isMocked, this.timestamp);
  final double latitude;
  final double longitude;
  final double accuracy;
  final bool isMocked;
  final DateTime timestamp;
}

enum LocationProblem { serviceDisabled, denied, deniedForever, timeout }

class LocationFailed extends LocationResult {
  const LocationFailed(this.problem);
  final LocationProblem problem;
  String get message => switch (problem) {
        LocationProblem.serviceDisabled => S.locationDisabled,
        LocationProblem.denied => S.locationDenied,
        LocationProblem.deniedForever => S.locationDeniedForever,
        LocationProblem.timeout => S.locationTimeout,
      };
  bool get canOpenSettings => problem == LocationProblem.deniedForever || problem == LocationProblem.serviceDisabled;
}

/// Location only at the moment of an event — never continuous tracking.
class LocationService {
  Future<LocationResult> current({Duration timeout = const Duration(seconds: 20)}) async {
    if (!await Geolocator.isLocationServiceEnabled()) return const LocationFailed(LocationProblem.serviceDisabled);
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) return const LocationFailed(LocationProblem.denied);
    if (permission == LocationPermission.deniedForever) return const LocationFailed(LocationProblem.deniedForever);
    try {
      final p = await Geolocator.getCurrentPosition(locationSettings: LocationSettings(accuracy: LocationAccuracy.high, timeLimit: timeout));
      return LocationOk(p.latitude, p.longitude, p.accuracy, p.isMocked, p.timestamp);
    } on TimeoutException {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && DateTime.now().difference(last.timestamp) < const Duration(minutes: 3)) {
        return LocationOk(last.latitude, last.longitude, last.accuracy, last.isMocked, last.timestamp);
      }
      return const LocationFailed(LocationProblem.timeout);
    } catch (_) {
      return const LocationFailed(LocationProblem.timeout);
    }
  }

  Future<void> openSettings(LocationProblem p) async {
    if (p == LocationProblem.serviceDisabled) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }
}

/// Same haversine + accuracy rule as the server (backend/src/common/utils/geo.ts), so the worker gets
/// an immediate answer offline instead of a rejection hours later.
double distanceMeters(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371008.8;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLon = rad(lon2 - lon1);
  final a = math.pow(math.sin(dLat / 2), 2) + math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLon / 2), 2);
  return 2 * r * math.asin(math.min(1, math.sqrt(a)));
}

enum GeofenceVerdict { inside, uncertain, outside }

GeofenceVerdict geofenceVerdict(double distance, int radius, double? accuracy) {
  if (distance <= radius) return GeofenceVerdict.inside;
  final acc = math.max(0.0, math.min(accuracy ?? 0, 500.0));
  return distance - acc <= radius ? GeofenceVerdict.uncertain : GeofenceVerdict.outside;
}
