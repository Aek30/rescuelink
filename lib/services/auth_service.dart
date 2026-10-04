import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'account_storage.dart';
import 'local_database_service.dart';
import 'app_preferences.dart';

class AccountSession {
  const AccountSession(this.userId, this.email, this.serialized);
  final String userId, email, serialized;
}

abstract interface class AuthBackend {
  Future<AccountSession?> authenticate(
    String email,
    String password, {
    required bool register,
    String? displayName,
  });
  Future<AccountSession> restore(String serialized);
  Future<void> linkInstallation(
    AccountSession session,
    String installationId,
    String radioIdentity,
  );
  Future<void> signOut();
}

abstract interface class SessionVault {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> clear();
}

class SecureSessionVault implements SessionVault {
  const SecureSessionVault();
  static const _storage = FlutterSecureStorage();
  static const _project = String.fromEnvironment('SUPABASE_URL');
  static const _key = 'rescuelink.auth.session.v1.$_project';
  @override
  Future<String?> read() => _storage.read(key: _key);
  @override
  Future<void> write(String value) => _storage.write(key: _key, value: value);
  @override
  Future<void> clear() => _storage.delete(key: _key);
}

/// PKCE verifiers are separate from remembered account sessions. Signup needs
/// this storage before it can send any HTTP request, even with Remember off.
class SecurePkceStorage extends GotrueAsyncStorage {
  const SecurePkceStorage(this.project);
  final String project;
  static const _storage = FlutterSecureStorage();
  String _key(String key) => 'rescuelink.auth.pkce.$project.$key';
  @override
  Future<String?> getItem({required String key}) =>
      _storage.read(key: _key(key));
  @override
  Future<void> setItem({required String key, required String value}) =>
      _storage.write(key: _key(key), value: value);
  @override
  Future<void> removeItem({required String key}) =>
      _storage.delete(key: _key(key));
}

class SupabaseAuthBackend implements AuthBackend {
  SupabaseAuthBackend(this.url, this.key, {GotrueAsyncStorage? pkceStorage})
    : _pkceStorage = pkceStorage ?? SecurePkceStorage(url);
  final String url, key;
  final GotrueAsyncStorage _pkceStorage;
  SupabaseClient? _client;
  SupabaseClient get client =>
      _client ?? (throw StateError('กรุณาเข้าสู่ระบบใหม่'));
  SupabaseClient _newClient() => SupabaseClient(
    url,
    key,
    authOptions: AuthClientOptions(
      autoRefreshToken: false,
      authFlowType: AuthFlowType.pkce,
      pkceAsyncStorage: _pkceStorage,
    ),
  );
  AccountSession _convert(Session s) =>
      AccountSession(s.user.id, s.user.email ?? '', jsonEncode(s.toJson()));
  @override
  Future<AccountSession?> authenticate(
    String email,
    String password, {
    required bool register,
    String? displayName,
  }) async {
    final client = _newClient();
    _client = client;
    final response = register
        ? await client.auth.signUp(
            email: email,
            password: password,
            data: {'display_name': displayName?.trim() ?? ''},
          )
        : await client.auth.signInWithPassword(
            email: email,
            password: password,
          );
    return response.session == null ? null : _convert(response.session!);
  }

  @override
  Future<AccountSession> restore(String serialized) async {
    final client = _newClient();
    _client = client;
    final saved = Session.fromJson(
      jsonDecode(serialized) as Map<String, dynamic>,
    );
    if (saved == null ||
        saved.refreshToken == null ||
        saved.expiresAt == null) {
      throw const AuthException('Session missing');
    }
    final response = saved.isExpired
        ? await client.auth.setSession(saved.refreshToken!)
        : await client.auth.recoverSession(serialized);
    if (response.session == null) throw const AuthException('Session expired');
    return _convert(response.session!);
  }

  @override
  Future<void> linkInstallation(
    AccountSession session,
    String installationId,
    String radioIdentity,
  ) async {
    final client = _newClient();
    try {
      await client.auth.recoverSession(session.serialized);
      final name = client.auth.currentUser?.userMetadata?['display_name'];
      if (name is String && name.trim().isNotEmpty) {
        await client
            .from('profiles')
            .update({'display_name': name.trim()})
            .eq('id', session.userId)
            .eq('display_name', '');
      }
      await client.from('account_devices').upsert({
        'user_id': session.userId,
        'installation_id': installationId,
        'radio_identity': radioIdentity,
        'last_seen_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id,installation_id');
    } finally {
      await client.dispose();
    }
  }

  @override
  Future<void> signOut() async {
    // Best effort server revocation. Local vault removal is mandatory first.
    final client = _client;
    _client = null;
    if (client == null) return;
    try {
      await client.auth.signOut(scope: SignOutScope.local);
    } finally {
      await client.dispose();
    }
  }
}

class AuthService extends ChangeNotifier {
  AuthService({required this.storage, required this.vault, this.backend});
  static final instance = AuthService(
    storage: AccountStorage(),
    vault: const SecureSessionVault(),
    backend: _configuredBackend(),
  );
  static AuthBackend? _configuredBackend() {
    const url = String.fromEnvironment('SUPABASE_URL');
    const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
    if (url.isEmpty || key.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
    return SupabaseAuthBackend(url, key);
  }

  final AccountStorage storage;
  final SessionVault vault;
  final AuthBackend? backend;
  AccountSession? session;
  bool busy = false;
  String? error;
  String? notice;
  Future<void>? _initializing;
  final _restoreCanceled = Completer<AccountSession?>();
  Future<void> enterGuestFromStartup() async {
    if (!_restoreCanceled.isCompleted) _restoreCanceled.complete(null);
    await initialize();
    if (signedIn) await signOut();
  }

  bool get configured => backend != null;
  bool get signedIn => session != null;

  Future<SupabaseClient>? _cloudAccess;
  bool _signingOut = false;
  Future<SupabaseClient> cloudClient(String owner) {
    if (_signingOut || session?.userId != owner) {
      return Future.error(StateError('บัญชีเปลี่ยนแล้ว'));
    }
    return _cloudAccess ??= _getCloudClient(
      owner,
    ).whenComplete(() => _cloudAccess = null);
  }

  Future<SupabaseClient> _getCloudClient(String owner) async {
    final original = session;
    if (original == null ||
        original.userId != owner ||
        backend is! SupabaseAuthBackend) {
      throw StateError('กรุณาเข้าสู่ระบบเพื่อซิงก์');
    }
    final client = (backend as SupabaseAuthBackend).client;
    if (client.auth.currentSession?.isExpired != false) {
      final refreshed = await client.auth.refreshSession().timeout(
        const Duration(seconds: 15),
      );
      if (!identical(session, original)) throw StateError('บัญชีเปลี่ยนแล้ว');
      if (refreshed.session == null) throw StateError('กรุณาเข้าสู่ระบบใหม่');
      final value = AccountSession(
        owner,
        original.email,
        jsonEncode(refreshed.session!.toJson()),
      );
      if (await vault.read() != null) {
        if (!identical(session, original)) throw StateError('บัญชีเปลี่ยนแล้ว');
        await vault.write(value.serialized);
      }
      if (!identical(session, original)) throw StateError('บัญชีเปลี่ยนแล้ว');
      session = value;
    }
    if (session?.userId != owner || client.auth.currentUser?.id != owner) {
      throw StateError('บัญชีเปลี่ยนแล้ว');
    }
    return client;
  }

  Future<void> initialize() => _initializing ??= _restore();
  Future<void> _restore() async {
    // Never fall back to legacy rescuelink.db if its ownership catalog fails:
    // that file may already belong to a member after Guest adoption.
    LocalDatabaseService.instance = LocalDatabaseService(
      factory: storage.factory,
      blocked: true,
    );
    try {
      LocalDatabaseService.instance = await storage.select(null);
      if (backend == null) return;
      final saved = await vault.read();
      if (saved == null) return;
      final recovered = await Future.any<AccountSession?>([
        backend!.restore(saved).timeout(const Duration(seconds: 15)),
        _restoreCanceled.future,
      ]);
      if (recovered == null || _restoreCanceled.isCompleted) return;
      final handle = await storage.select(recovered.userId);
      await vault.write(recovered.serialized);
      LocalDatabaseService.instance = handle;
      session = recovered;
    } catch (_) {
      // Never unlock a previous account on a failed/expired recovery.
      error = 'กู้ session ไม่สำเร็จ กรุณาเข้าสู่ระบบใหม่ หรือใช้งานแบบ Guest';
    }
    notifyListeners();
  }

  Future<bool> authenticate(
    String email,
    String password, {
    required bool register,
    required bool remember,
    required bool claimGuest,
    String? displayName,
  }) async {
    if (busy || signedIn) return false;
    if (backend == null) {
      error = 'ระบบบัญชียังไม่พร้อมใช้งาน';
      notifyListeners();
      return false;
    }
    busy = true;
    error = null;
    notice = null;
    notifyListeners();
    try {
      final result = await backend!
          .authenticate(
            email.trim(),
            password,
            register: register,
            displayName: register ? displayName?.trim() : null,
          )
          .timeout(const Duration(seconds: 20));
      if (result == null) {
        notice =
            'ตรวจสอบอีเมลเพื่อยืนยันบัญชี รวมถึงโฟลเดอร์สแปม แล้วกลับมาเข้าสู่ระบบ หากเคยสมัครแล้วให้ใช้บัญชีเดิม';
        return false;
      }
      // Persist before claiming: a secure-storage failure must not transfer data.
      if (remember) {
        await vault.write(result.serialized);
      } else {
        await vault.clear();
      }
      final handle = await storage.select(
        result.userId,
        claimGuest: claimGuest,
      );
      LocalDatabaseService.instance = handle;
      session = result;
      AppPreferences.instance.reset();
      await AppPreferences.instance.load().catchError((Object _) {});
      // Metadata only; local SOS/history is never uploaded or gated on this.
      try {
        await backend!
            .linkInstallation(
              result,
              await storage.installationId,
              await handle.getDeviceId(),
            )
            .timeout(const Duration(seconds: 5));
      } catch (_) {
        error = 'เข้าสู่ระบบแล้ว แต่ยังเชื่อมข้อมูลเครื่องกับ Cloud ไม่สำเร็จ';
      }
      return true;
    } on AuthRetryableFetchException {
      error =
          'ติดต่อระบบบัญชีไม่ได้ กรุณาตรวจสอบอินเทอร์เน็ตแล้วลองใหม่ ยังใช้งานแบบ Guest ได้';
    } on AuthException catch (e) {
      error = switch (e.code) {
        'invalid_credentials' => 'อีเมลหรือรหัสผ่านไม่ถูกต้อง',
        'email_not_confirmed' => 'กรุณายืนยันอีเมลก่อนเข้าสู่ระบบ',
        'user_already_exists' => 'อีเมลนี้ถูกใช้งานแล้ว',
        'over_request_rate_limit' ||
        'over_email_send_rate_limit' => 'ลองหลายครั้งเกินไป กรุณารอสักครู่',
        'weak_password' => 'รหัสผ่านไม่ผ่านเงื่อนไขความปลอดภัย',
        'email_address_not_authorized' =>
          'ระบบยังส่งอีเมลยืนยันไปยังอีเมลใหม่ไม่ได้ กรุณาแจ้งผู้ดูแลตั้งค่าบริการส่งอีเมล ระหว่างนี้ใช้งานแบบ Guest ได้',
        'email_address_invalid' =>
          'อีเมลนี้ไม่สามารถใช้สมัครได้ กรุณาตรวจสอบอีเมล',
        'signup_disabled' => 'ระบบปิดรับสมัครชั่วคราว ยังใช้งานแบบ Guest ได้',
        'unexpected_failure' =>
          'ระบบสมัครสมาชิกขัดข้อง กรุณาลองภายหลังหรือแจ้งผู้ดูแล',
        _ => 'ยืนยันตัวตนไม่สำเร็จ กรุณาตรวจสอบข้อมูลแล้วลองใหม่',
      };
    } on StateError catch (e) {
      error = e.message;
    } on TimeoutException {
      error =
          'การเชื่อมต่อหมดเวลา หากสมัครแล้วให้ตรวจอีเมลยืนยันก่อนลองอีกครั้ง หรือใช้งานแบบ Guest';
    } on SocketException {
      error =
          'เชื่อมต่ออินเทอร์เน็ตไม่ได้ กรุณาตรวจสอบ Wi-Fi หรือข้อมูลมือถือ ยังใช้งานแบบ Guest ได้';
    } on HandshakeException {
      error =
          'เชื่อมต่ออย่างปลอดภัยไม่ได้ กรุณาตรวจวันเวลาในเครื่องหรือเปลี่ยนเครือข่าย';
    } on PlatformException {
      error =
          'เข้าถึงที่เก็บข้อมูลปลอดภัยในเครื่องไม่ได้ กรุณาปิดเปิดแอปแล้วลองใหม่ ยังใช้งานแบบ Guest ได้';
    } catch (e) {
      // Record only the type: exception messages can contain credentials.
      debugPrint('Authentication failed: ${e.runtimeType}');
      error =
          'ดำเนินการไม่สำเร็จ หากสมัครแล้วให้ตรวจอีเมลยืนยันก่อน จากนั้นลองเข้าสู่ระบบ หรือใช้งานแบบ Guest';
    } finally {
      if (session == null) {
        try {
          await vault.clear();
        } catch (_) {}
      }
      busy = false;
      notifyListeners();
    }
    return false;
  }

  /// Caller stops Nearby before changing scope. No network is needed to exit.
  Future<void> signOut() async {
    if (busy) throw StateError('กรุณารอการเข้าสู่ระบบให้เสร็จ');
    _signingOut = true;
    try {
      try {
        await _cloudAccess;
      } catch (_) {}
      await vault
          .clear(); // Fail closed if persisted credentials cannot be removed.
      final guest = await storage.select(null);
      session = null;
      LocalDatabaseService.instance = guest;
      AppPreferences.instance.reset();
      await AppPreferences.instance.load().catchError((Object _) {});
      error = null;
      notifyListeners();
      // Do not let late server responses mutate local ownership/session state.
      unawaited(
        backend
                ?.signOut()
                .timeout(const Duration(seconds: 5))
                .catchError((Object _) {}) ??
            Future<void>.value(),
      );
    } finally {
      _signingOut = false;
    }
  }
}
