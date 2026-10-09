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
import 'emergency_profile_store.dart';

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
    Map<String, dynamic>? extraMetadata,
  });
  Future<AccountSession> restore(String serialized);
  Future<void> linkInstallation(
    AccountSession session,
    String installationId,
    String radioIdentity,
  );
  Future<void> signOut();
  Future<void> sendPasswordResetEmail(String email);
  Future<void> resendConfirmation(String email);
  Future<void> resetPasswordWithOtp({
    required String email,
    required String token,
    required String newPassword,
  });
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
  SupabaseAuthBackend(
    this.url,
    this.key, {
    GotrueAsyncStorage? pkceStorage,
    EmergencyProfileStore? profiles,
  }) : _pkceStorage = pkceStorage ?? SecurePkceStorage(url),
       profiles = profiles ?? EmergencyProfileStore(SecureProfileVault(url));
  final EmergencyProfileStore profiles;
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
    Map<String, dynamic>? extraMetadata,
  }) async {
    final profile = register && extraMetadata != null
        ? normalizeProfile(extraMetadata)
        : null;
    final client = _newClient();
    _client = client;
    final response = register
        ? await client.auth.signUp(
            email: email,
            password: password,
            data: {
              'display_name': displayName?.trim() ?? '',
              if (profile != null)
                for (final field in [
                  'full_name',
                  'phone',
                  'date_of_birth',
                  'terms_version',
                ])
                  field: profile[field],
            },
          )
        : await client.auth.signInWithPassword(
            email: email,
            password: password,
          );
    final user = response.user;
    // Duplicate signup can return an obfuscated user. Never replace old data.
    if (register &&
        profile != null &&
        user != null &&
        (response.session != null || user.identities?.isNotEmpty == true)) {
      await profiles.save(user.id, profile);
    }
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
    AuthResponse response;
    try {
      response = saved.isExpired
          ? await client.auth
                .setSession(saved.refreshToken!)
                .timeout(const Duration(seconds: 8))
          : await client.auth.recoverSession(serialized);
    } catch (e) {
      if ((e is AuthRetryableFetchException ||
              e is SocketException ||
              e is TimeoutException) &&
          saved.user.emailConfirmedAt != null &&
          !saved.user.isAnonymous) {
        // The secure vault contains a previously authenticated identity. Only
        // local radio/storage is unlocked; Cloud still requires a refresh.
        return _convert(saved);
      }
      rethrow;
    }
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

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    final client = _newClient();
    try {
      await client.auth.resetPasswordForEmail(email.trim());
    } finally {
      await client.dispose();
    }
  }

  @override
  Future<void> resendConfirmation(String email) async {
    final client = _newClient();
    try {
      await client.auth.resend(type: OtpType.signup, email: email.trim());
    } finally {
      await client.dispose();
    }
  }

  @override
  Future<void> resetPasswordWithOtp({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    final client = _newClient();
    try {
      var raw = token.trim();
      if (raw.startsWith('http://') || raw.startsWith('https://')) {
        final uri = Uri.tryParse(raw);
        if (uri != null) {
          raw =
              uri.queryParameters['token'] ??
              uri.queryParameters['token_hash'] ??
              uri.queryParameters['code'] ??
              raw;
        }
      }
      final response = raw.length > 10
          ? await client.auth.verifyOTP(tokenHash: raw, type: OtpType.recovery)
          : await client.auth.verifyOTP(
              email: email.trim(),
              token: raw,
              type: OtpType.recovery,
            );
      if (response.session == null) {
        throw const AuthException('รหัสยืนยันไม่ถูกต้องหรือหมดอายุ');
      }
      await client.auth.updateUser(UserAttributes(password: newPassword));
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
      AuthResponse refreshed;
      try {
        final saved = Session.fromJson(
          jsonDecode(original.serialized) as Map<String, dynamic>,
        );
        refreshed = await client.auth
            .refreshSession(saved?.refreshToken)
            .timeout(const Duration(seconds: 15));
      } on AuthException catch (e) {
        if (e is! AuthRetryableFetchException &&
            const [
              'refresh_token_not_found',
              'refresh_token_already_used',
              'session_not_found',
              'user_banned',
              'user_not_found',
              'bad_jwt',
              'session_expired',
            ].contains(e.code)) {
          await _invalidate(original);
        }
        rethrow;
      }
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
    // Pending profile writes retry with ordinary Cloud access, without gating
    // Chat/SOS sync on the availability of the profile endpoint.
    try {
      await (backend as SupabaseAuthBackend).profiles
          .sync(client, owner, () => !_signingOut && session?.userId == owner)
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
    return client;
  }

  Future<void> _invalidate(AccountSession original) async {
    if (!identical(session, original)) return;
    await vault.clear();
    session = null;
    LocalDatabaseService.instance = LocalDatabaseService(
      factory: storage.factory,
      blocked: true,
    );
    error = 'บัญชีหมดอายุหรือถูกยกเลิก กรุณาเข้าสู่ระบบใหม่';
    notifyListeners();
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
      final recovered = await backend!
          .restore(saved)
          .timeout(const Duration(seconds: 15));
      final handle = await storage.select(recovered.userId);
      await vault.write(recovered.serialized);
      LocalDatabaseService.instance = handle;
      session = recovered;
    } catch (e) {
      if (e is AuthException && e is! AuthRetryableFetchException) {
        try {
          await vault.clear();
        } catch (_) {}
      }
      // Never unlock a previous account on a failed/expired recovery.
      error = 'กู้ session ไม่สำเร็จ กรุณาเข้าสู่ระบบใหม่';
    }
    notifyListeners();
  }

  Future<bool> authenticate(
    String email,
    String password, {
    required bool register,
    required bool remember,
    String? displayName,
    Map<String, dynamic>? extraMetadata,
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
            extraMetadata: register ? extraMetadata : null,
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
      final handle = await storage.select(result.userId, claimGuest: false);
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
      error = 'ติดต่อระบบบัญชีไม่ได้ กรุณาตรวจสอบอินเทอร์เน็ตแล้วลองใหม่';
    } on AuthException catch (e) {
      if (e.code == 'email_not_confirmed') {
        notice = 'กรุณายืนยันอีเมลก่อนเข้าสู่ระบบ';
      }
      error = switch (e.code) {
        'invalid_credentials' => 'อีเมลหรือรหัสผ่านไม่ถูกต้อง',
        'email_not_confirmed' => 'กรุณายืนยันอีเมลก่อนเข้าสู่ระบบ',
        'user_already_exists' =>
          'อีเมลนี้ถูกใช้งานแล้ว กรุณาเข้าสู่ระบบด้วยบัญชีเดิม',
        'over_request_rate_limit' || 'over_email_send_rate_limit' =>
          'ลองหลายครั้งเกินไป กรุณารอสักครู่แล้วลองใหม่',
        'weak_password' =>
          'รหัสผ่านไม่ผ่านเงื่อนไขความปลอดภัย กรุณาใช้รหัสผ่านที่แข็งแกร่งขึ้น',
        'email_address_not_authorized' =>
          'ระบบยังส่งอีเมลยืนยันไปยังอีเมลนี้ไม่ได้ กรุณาแจ้งผู้ดูแลตั้งค่าบริการส่งอีเมล',
        'email_address_invalid' =>
          'อีเมลนี้ไม่สามารถใช้สมัครได้ กรุณาตรวจสอบอีเมลให้ถูกต้อง',
        'signup_disabled' => 'ระบบปิดรับสมัครชั่วคราว กรุณาลองใหม่ภายหลัง',
        'unexpected_failure' =>
          'ระบบสมัครสมาชิกขัดข้อง กรุณาลองภายหลังหรือแจ้งผู้ดูแล',
        _ => 'ยืนยันตัวตนไม่สำเร็จ กรุณาตรวจสอบข้อมูลแล้วลองใหม่',
      };
    } on StateError catch (e) {
      error = e.message;
    } on TimeoutException {
      error =
          'การเชื่อมต่อหมดเวลา หากสมัครแล้วให้ตรวจอีเมลยืนยันก่อนลองอีกครั้ง';
    } on SocketException {
      error = 'เชื่อมต่ออินเทอร์เน็ตไม่ได้ กรุณาตรวจสอบ Wi-Fi หรือข้อมูลมือถือ';
    } on HandshakeException {
      error =
          'เชื่อมต่ออย่างปลอดภัยไม่ได้ กรุณาตรวจวันเวลาในเครื่องหรือเปลี่ยนเครือข่าย';
    } on PlatformException {
      error =
          'เข้าถึงที่เก็บข้อมูลปลอดภัยในเครื่องไม่ได้ กรุณาปิดเปิดแอปแล้วลองใหม่';
    } catch (e) {
      // Record only the type: exception messages can contain credentials.
      debugPrint('Authentication failed: ${e.runtimeType}');
      error =
          'ดำเนินการไม่สำเร็จ หากสมัครแล้วให้ตรวจอีเมลยืนยันก่อน จากนั้นลองเข้าสู่ระบบ';
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

  Future<void> sendPasswordResetEmail(String email) async {
    if (backend == null) {
      throw StateError('ระบบบัญชียังไม่พร้อมใช้งาน');
    }
    await backend!.sendPasswordResetEmail(email.trim());
  }

  final _resendAfter = <String, DateTime>{};
  bool _resending = false;
  Future<void> resendConfirmation(String email) async {
    if (backend == null) throw StateError('ระบบบัญชียังไม่พร้อมใช้งาน');
    final value = email.trim().toLowerCase();
    if (_resending ||
        DateTime.now().isBefore(_resendAfter[value] ?? DateTime(1970))) {
      throw StateError('กรุณารอ 60 วินาทีก่อนส่งอีเมลอีกครั้ง');
    }
    _resending = true;
    _resendAfter[value] = DateTime.now().add(const Duration(seconds: 60));
    try {
      await backend!
          .resendConfirmation(email.trim())
          .timeout(const Duration(seconds: 20));
    } finally {
      _resending = false;
    }
  }

  Future<void> resetPasswordWithOtp({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    if (backend == null) {
      throw StateError('ระบบบัญชียังไม่พร้อมใช้งาน');
    }
    await backend!.resetPasswordWithOtp(
      email: email.trim(),
      token: token.trim(),
      newPassword: newPassword,
    );
  }
}
