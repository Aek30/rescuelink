import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

class MemberProfile {
  const MemberProfile({
    required this.id,
    required this.email,
    required this.name,
  });
  final String id, email, name;
}

abstract interface class MemberRepository {
  Future<MemberProfile> read();
  Future<MemberProfile> updateName(String name);
  Future<void> deleteAccount(String password);
}

class SupabaseMemberRepository implements MemberRepository {
  SupabaseMemberRepository(this.auth);
  final AuthService auth;

  String get _owner =>
      auth.session?.userId ?? (throw StateError('กรุณาเข้าสู่ระบบก่อน'));

  @override
  Future<MemberProfile> read() async {
    final owner = _owner;
    final client = await auth.cloudClient(owner);
    final row = await client
        .from('profiles')
        .select('id, display_name')
        .eq('id', owner)
        .single();
    if (_owner != owner) throw StateError('บัญชีเปลี่ยนแล้ว');
    return MemberProfile(
      id: owner,
      email: auth.session!.email,
      name: row['display_name'] as String,
    );
  }

  @override
  Future<MemberProfile> updateName(String name) async {
    name = name.trim();
    if (name.isEmpty || name.length > 100) {
      throw StateError('กรุณาระบุชื่อ 1–100 ตัวอักษร');
    }
    final owner = _owner;
    final client = await auth.cloudClient(owner);
    final row = await client
        .from('profiles')
        .update({'display_name': name})
        .eq('id', owner)
        .select('id, display_name')
        .single();
    if (_owner != owner) throw StateError('บัญชีเปลี่ยนแล้ว');
    return MemberProfile(
      id: owner,
      email: auth.session!.email,
      name: row['display_name'] as String,
    );
  }

  @override
  Future<void> deleteAccount(String password) async {
    if (password.isEmpty) throw StateError('กรุณากรอกรหัสผ่านเพื่อยืนยัน');
    final owner = _owner;
    final client = await auth.cloudClient(owner);
    final response = await client.functions.invoke(
      'delete-account',
      body: {'password': password, 'confirmation': 'DELETE'},
    );
    if (response.status != 200 ||
        response.data is! Map ||
        response.data['deleted'] != true) {
      throw StateError('ลบบัญชีไม่สำเร็จ กรุณาลองใหม่');
    }
    if (auth.session?.userId != owner) throw StateError('บัญชีเปลี่ยนแล้ว');
    await auth.signOut();
    if (auth.backend is SupabaseAuthBackend) {
      await (auth.backend as SupabaseAuthBackend).profiles.vault.remove(owner);
    }
    await auth.storage.removeOwner(owner);
  }
}

String memberError(Object error) {
  if (error is StateError) return error.message.toString();
  if (error is FunctionException) {
    if (error.status == 401) return 'session หมดอายุ กรุณาเข้าสู่ระบบใหม่';
    if (error.status == 403) return 'รหัสผ่านไม่ถูกต้อง บัญชียังไม่ถูกลบ';
    return 'ลบบัญชีไม่สำเร็จ ตรวจสอบอินเทอร์เน็ตแล้วลองใหม่';
  }
  return 'ติดต่อฐานข้อมูลไม่สำเร็จ ตรวจสอบอินเทอร์เน็ตแล้วลองใหม่';
}
