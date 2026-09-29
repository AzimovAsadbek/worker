import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

/// Random per-install id (not a hardware identifier — privacy friendly). Used only to flag
/// shared-device anomalies; one worker may use several devices and one device may serve several workers.
class DeviceIdStore {
  DeviceIdStore([FlutterSecureStorage? s]) : _s = s ?? const FlutterSecureStorage();
  final FlutterSecureStorage _s;
  String? _cached;

  Future<String> get() async {
    if (_cached != null) return _cached!;
    var id = await _s.read(key: 'device_id');
    if (id == null) {
      id = const Uuid().v4();
      await _s.write(key: 'device_id', value: id);
    }
    return _cached = id;
  }
}
