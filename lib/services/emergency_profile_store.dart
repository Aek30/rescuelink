import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

const healthFields = <String, int>{
  'medical_conditions': 2000,
  'allergies': 2000,
  'medications': 2000,
  'medical_notes': 2000,
  'emergency_contact_name': 200,
  'emergency_contact_phone': 30,
  'emergency_contact_relation': 100,
};
const bloodGroups = ['ไม่ทราบ', 'A', 'B', 'AB', 'O'];
const rhFactors = ['ไม่ทราบ', 'Positive (+)', 'Negative (-)'];
const privacyVersion = '2026-10-09';

abstract interface class ProfileVault {
  Future<String?> read(String owner);
  Future<void> write(String owner, String value);
  Future<void> remove(String owner);
}

/// Health data never goes into SQLite, Auth metadata/JWT, logs, or radio packets.
class SecureProfileVault implements ProfileVault {
  const SecureProfileVault(this.project);
  final String project;
  static const storage = FlutterSecureStorage();
  String _key(String owner) => 'rescuelink.private.profile.v1.$project.$owner';
  @override
  Future<String?> read(String owner) => storage.read(key: _key(owner));
  @override
  Future<void> write(String owner, String value) =>
      storage.write(key: _key(owner), value: value);
  @override
  Future<void> remove(String owner) => storage.delete(key: _key(owner));
}

Map<String, dynamic> normalizeProfile(Map<String, dynamic> input) {
  final result = <String, dynamic>{};
  for (final field in {
    'display_name': 100,
    'full_name': 200,
    'phone': 30,
  }.entries) {
    final value = (input[field.key] as String? ?? '').trim();
    if (value.length > field.value) throw StateError('ข้อมูลยาวเกินกำหนด');
    result[field.key] = value;
  }
  final dob = input['date_of_birth'] as String?;
  if (dob != null &&
      (DateTime.tryParse(dob) == null ||
          DateTime.parse(dob).isAfter(DateTime.now()))) {
    throw StateError('วันเดือนปีเกิดไม่ถูกต้อง');
  }
  result['date_of_birth'] = dob;
  result['terms_version'] = input['terms_version'] == privacyVersion
      ? privacyVersion
      : null;
  final consent = input['health_consent'] == true;
  result['health_consent'] = consent;
  if (consent) {
    final blood = input['blood_group'] ?? 'ไม่ทราบ';
    final rh = input['rh_factor'] ?? 'ไม่ทราบ';
    if (!bloodGroups.contains(blood) || !rhFactors.contains(rh)) {
      throw StateError('กรุ๊ปเลือดหรือ Rh ไม่ถูกต้อง');
    }
    result['blood_group'] = blood;
    result['rh_factor'] = rh;
    for (final field in healthFields.entries) {
      final value = (input[field.key] as String? ?? '').trim();
      if (value.length > field.value) {
        throw StateError('ข้อมูลสุขภาพยาวเกินกำหนด');
      }
      result[field.key] = value.isEmpty ? null : value;
    }
  }
  return result;
}

class EmergencyProfileStore {
  EmergencyProfileStore(this.vault);
  final ProfileVault vault;
  final _uploading = <String, Future<void>>{};
  final _locks = <String, Future<void>>{};

  Future<T> _locked<T>(String owner, Future<T> Function() action) async {
    final prior = _locks[owner] ?? Future<void>.value();
    final done = prior.then((_) => action());
    final barrier = done.then<void>((_) {}, onError: (Object _) {});
    _locks[owner] = barrier;
    try {
      return await done;
    } finally {
      if (identical(_locks[owner], barrier)) _locks.remove(owner);
    }
  }

  Future<Map<String, dynamic>?> record(String owner) =>
      _locked(owner, () => _record(owner));
  Future<Map<String, dynamic>?> _record(String owner) async {
    final raw = await vault.read(owner);
    if (raw == null) return null;
    final value = jsonDecode(raw) as Map<String, dynamic>;
    if (value['owner'] != owner) {
      throw StateError('บัญชีไม่ตรงกับข้อมูลในเครื่อง');
    }
    return value;
  }

  Future<void> save(
    String owner,
    Map<String, dynamic> data, {
    bool pending = true,
  }) => _locked(
    owner,
    () => vault.write(
      owner,
      jsonEncode({
        'owner': owner,
        'revision': const Uuid().v4(),
        'pending': pending,
        'data': normalizeProfile(data),
      }),
    ),
  );

  Future<void> sync(
    SupabaseClient client,
    String owner,
    bool Function() active,
  ) => _uploading[owner] ??= _sync(client, owner, active).whenComplete(() {
    _uploading.remove(owner);
  });

  Future<void> _sync(
    SupabaseClient client,
    String owner,
    bool Function() active,
  ) async {
    final before = await record(owner);
    if (before == null || before['pending'] != true) return;
    if (!active() || client.auth.currentUser?.id != owner) {
      throw StateError('บัญชีเปลี่ยนแล้ว');
    }
    await client
        .rpc('save_rescue_profile', params: {'p_data': before['data']})
        .timeout(const Duration(seconds: 20));
    if (!active()) return;
    // A late upload must not acknowledge a newer edit or consent withdrawal.
    await _locked(owner, () async {
      if (!active()) return;
      final latest = await _record(owner);
      if (latest?['revision'] == before['revision']) {
        before['pending'] = false;
        await vault.write(owner, jsonEncode(before));
      }
    });
  }
}
