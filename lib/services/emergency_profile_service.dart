import 'auth_service.dart';
import 'emergency_profile_store.dart';

class EmergencyProfileResult {
  const EmergencyProfileResult(
    this.data, {
    this.pending = false,
    this.offline = false,
  });
  final Map<String, dynamic> data;
  final bool pending, offline;
}

abstract interface class EmergencyProfileRepository {
  Future<EmergencyProfileResult> read();
  Future<EmergencyProfileResult> save(Map<String, dynamic> data);
  Future<EmergencyProfileResult> deleteHealth();
}

class SupabaseEmergencyProfileRepository implements EmergencyProfileRepository {
  SupabaseEmergencyProfileRepository(this.auth, {EmergencyProfileStore? store})
    : store = store ?? (auth.backend as SupabaseAuthBackend).profiles;
  final AuthService auth;
  final EmergencyProfileStore store;
  String get owner =>
      auth.session?.userId ?? (throw StateError('กรุณาเข้าสู่ระบบก่อน'));
  void _check(String id) {
    if (auth.session?.userId != id) throw StateError('บัญชีเปลี่ยนแล้ว');
  }

  @override
  Future<EmergencyProfileResult> read() async {
    final id = owner;
    final cached = await store.record(id);
    _check(id);
    try {
      final client = await auth.cloudClient(id);
      _check(id);
      // Do not replace a queued offline edit with an older server record.
      final current = await store.record(id);
      if (current?['pending'] == true) {
        return EmergencyProfileResult(
          Map<String, dynamic>.from(current!['data']),
          pending: true,
        );
      }
      final personal = await client
          .from('profiles')
          .select(
            'display_name, full_name, phone, date_of_birth, terms_version',
          )
          .eq('id', id)
          .single()
          .timeout(const Duration(seconds: 15));
      final health = await client
          .from('emergency_medical_profiles')
          .select()
          .eq('id', id)
          .maybeSingle()
          .timeout(const Duration(seconds: 15));
      _check(id);
      final data = normalizeProfile({...personal, ...?health});
      await store.save(id, data, pending: false);
      _check(id);
      return EmergencyProfileResult(data);
    } catch (_) {
      _check(id);
      final current = await store.record(id) ?? cached;
      if (current == null) {
        throw StateError(
          'ยังไม่มีข้อมูลในเครื่อง กรุณาเชื่อมต่ออินเทอร์เน็ตเพื่อโหลดครั้งแรก',
        );
      }
      return EmergencyProfileResult(
        Map<String, dynamic>.from(current['data']),
        pending: current['pending'] == true,
        offline: true,
      );
    }
  }

  @override
  Future<EmergencyProfileResult> save(Map<String, dynamic> data) async {
    final id = owner;
    final normalized = normalizeProfile(data);
    if ((normalized['display_name'] as String).isEmpty ||
        (normalized['full_name'] as String).isEmpty) {
      throw StateError('กรุณากรอกชื่อ-นามสกุลและชื่อที่แสดง');
    }
    await store.save(id, normalized);
    _check(id);
    return _upload(id, normalized);
  }

  Future<EmergencyProfileResult> _upload(
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      final client = await auth.cloudClient(id);
      await store.sync(client, id, () => auth.session?.userId == id);
      _check(id);
      final latest = await store.record(id);
      return EmergencyProfileResult(data, pending: latest?['pending'] == true);
    } catch (_) {
      _check(id);
      return EmergencyProfileResult(data, pending: true, offline: true);
    }
  }

  @override
  Future<EmergencyProfileResult> deleteHealth() async {
    final id = owner;
    final cached = await store.record(id);
    final current = cached != null
        ? EmergencyProfileResult(Map<String, dynamic>.from(cached['data']))
        : await read();
    _check(id);
    // Wipe all local medical fields immediately, keeping personal/account data.
    final data = normalizeProfile({...current.data, 'health_consent': false});
    await store.save(id, data);
    _check(id);
    return _upload(id, data);
  }
}
