import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../services/emergency_profile_store.dart';
import '../widgets/privacy_notice.dart';
import 'nearby_test_screen.dart';

// ────────────────────────────────────────────────────────────
// Helpers
// ────────────────────────────────────────────────────────────

String _maskEmail(String email) {
  final at = email.indexOf('@');
  if (at < 1) return '***';
  if (at == 1) return '*${email.substring(at)}';
  final local = email.substring(0, at);
  final domain = email.substring(at);
  if (local.length <= 2) return '${local[0]}*$domain';
  return '${local[0]}${'*' * (local.length - 2)}${local[local.length - 1]}$domain';
}

// ────────────────────────────────────────────────────────────
// Email-Verification Dialog
// ────────────────────────────────────────────────────────────

class EmailVerificationDialog extends StatefulWidget {
  const EmailVerificationDialog({
    super.key,
    required this.email,
    required this.onResend,
  });

  final String email;
  final Future<void> Function() onResend;

  static Future<void> show(
    BuildContext context, {
    required String email,
    required Future<void> Function() onResend,
  }) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => EmailVerificationDialog(email: email, onResend: onResend),
  );

  @override
  State<EmailVerificationDialog> createState() =>
      _EmailVerificationDialogState();
}

class _EmailVerificationDialogState extends State<EmailVerificationDialog> {
  static const _orange = Color(0xFFFFB37B);
  bool _sending = false;
  bool _success = false;
  String? _notice;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _cooldown = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_cooldown > 0) {
          _cooldown--;
        } else {
          _timer?.cancel();
        }
      });
    });
  }

  Future<void> _resend() async {
    if (_sending || _cooldown > 0) return;
    setState(() {
      _sending = true;
      _notice = null;
      _success = false;
    });
    try {
      await widget.onResend();
      if (!mounted) return;
      setState(() {
        _notice = 'ส่งอีเมลยืนยันแล้ว กรุณาตรวจสอบกล่องจดหมาย';
        _success = true;
      });
      _startCooldown();
    } on AuthException catch (e) {
      if (!mounted) return;
      final code = e.code ?? '';
      setState(() {
        _notice = code.contains('rate_limit') || e.statusCode == '429'
            ? 'ส่งบ่อยเกินไป กรุณารอสักครู่แล้วลองใหม่'
            : 'ส่งอีเมลไม่สำเร็จ กรุณาตรวจสอบอีเมลและลองใหม่';
      });
    } on StateError catch (e) {
      if (mounted) setState(() => _notice = e.message.toString());
    } on SocketException {
      if (!mounted) return;
      setState(() => _notice = 'ไม่มีอินเทอร์เน็ต กรุณาตรวจสอบการเชื่อมต่อ');
    } catch (_) {
      if (!mounted) return;
      setState(() => _notice = 'ส่งอีเมลไม่สำเร็จ กรุณาลองใหม่อีกครั้ง');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final masked = _maskEmail(widget.email);
    final success = _success;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? const Color(0xFF1E2631) : Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1A3A2A)
                    : const Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.mark_email_read_outlined,
                size: 38,
                color: Color(0xFF22C55E),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'ยืนยันอีเมลเพื่อเปิดใช้งานบัญชี',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF102D43),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'เราได้ส่งลิงก์ยืนยันไปยัง',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF555F6D),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0C1017)
                    : const Color(0xFFF0EBE3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                masked,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'กรุณาเปิดอีเมลและกดลิงก์ยืนยันก่อนเข้าสู่ระบบ\n'
              'หากไม่พบอีเมล ให้ตรวจโฟลเดอร์ Spam หรือ Junk',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.55,
                color: isDark
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF555F6D),
              ),
            ),
            if (_notice != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: success
                      ? (isDark
                            ? const Color(0xFF1A3A2A)
                            : const Color(0xFFE8F5E9))
                      : (isDark
                            ? const Color(0xFF3D181C)
                            : const Color(0xFFFFEBEE)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _notice!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: success
                        ? const Color(0xFF22C55E)
                        : const Color(0xFFE04C4C),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: (_sending || _cooldown > 0)
                      ? const LinearGradient(
                          colors: [Color(0xFFBBBBBB), Color(0xFFAAAAAA)],
                        )
                      : const LinearGradient(
                          colors: [Color(0xFFFFCBA4), Color(0xFFFFB37B)],
                        ),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: const Color(0xFF102D43),
                    shadowColor: Colors.transparent,
                    minimumSize: const Size.fromHeight(48),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: (_sending || _cooldown > 0) ? null : _resend,
                  child: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          _cooldown > 0
                              ? 'รอ ${_cooldown}s แล้วส่งใหม่'
                              : 'ส่งอีเมลยืนยันอีกครั้ง',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: _orange,
                  minimumSize: const Size.fromHeight(44),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'กลับไปหน้าเข้าสู่ระบบ',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Register Screen — 3-step wizard
// ────────────────────────────────────────────────────────────

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, this.auth});
  final AuthService? auth;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const _orange = Color(0xFFFFB37B);
  static const _navy = Color(0xFF102D43);

  int _step = 0;

  // Step 0
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  // Step 1
  final _fullNameCtrl = TextEditingController();
  final _displayNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  DateTime? _dob;
  // Step 2
  String _bloodGroup = 'ไม่ทราบ';
  String _rhFactor = 'ไม่ทราบ';
  final _conditionsCtrl = TextEditingController();
  final _allergiesCtrl = TextEditingController();
  final _medicationsCtrl = TextEditingController();
  final _medNotesCtrl = TextEditingController();
  final _emergencyNameCtrl = TextEditingController();
  final _emergencyPhoneCtrl = TextEditingController();
  final _emergencyRelCtrl = TextEditingController();

  bool _consentTerms = false;
  bool _consentHealth = false;

  bool _passwordHidden = true;
  bool _confirmHidden = true;
  bool _busy = false;
  String? _error;

  final _formKeys = [
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
  ];

  AuthService get _auth => widget.auth ?? AuthService.instance;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _fullNameCtrl.dispose();
    _displayNameCtrl.dispose();
    _phoneCtrl.dispose();
    _conditionsCtrl.dispose();
    _allergiesCtrl.dispose();
    _medicationsCtrl.dispose();
    _medNotesCtrl.dispose();
    _emergencyNameCtrl.dispose();
    _emergencyPhoneCtrl.dispose();
    _emergencyRelCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_busy) return;
    if (!_formKeys[_step].currentState!.validate()) return;
    if (_step < 2) {
      setState(() {
        _error = null;
        _step++;
      });
    } else {
      _submit();
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _submit() async {
    if (!_consentTerms) {
      setState(
        () => _error = 'กรุณายอมรับข้อกำหนดการใช้งานและนโยบายความเป็นส่วนตัว',
      );
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final displayName = _displayNameCtrl.text.trim().isNotEmpty
          ? _displayNameCtrl.text.trim()
          : _fullNameCtrl.text.trim();

      final extraMeta = <String, dynamic>{
        'terms_version': privacyVersion,
        'full_name': _fullNameCtrl.text.trim(),
        'display_name': displayName,
        if (_phoneCtrl.text.trim().isNotEmpty) 'phone': _phoneCtrl.text.trim(),
        if (_dob != null)
          'date_of_birth': _dob!.toIso8601String().substring(0, 10),
        if (_consentHealth) ...{
          'health_consent': true,
          'blood_group': _bloodGroup,
          'rh_factor': _rhFactor,
          if (_conditionsCtrl.text.trim().isNotEmpty)
            'medical_conditions': _conditionsCtrl.text.trim(),
          if (_allergiesCtrl.text.trim().isNotEmpty)
            'allergies': _allergiesCtrl.text.trim(),
          if (_medicationsCtrl.text.trim().isNotEmpty)
            'medications': _medicationsCtrl.text.trim(),
          if (_medNotesCtrl.text.trim().isNotEmpty)
            'medical_notes': _medNotesCtrl.text.trim(),
          if (_emergencyNameCtrl.text.trim().isNotEmpty)
            'emergency_contact_name': _emergencyNameCtrl.text.trim(),
          if (_emergencyPhoneCtrl.text.trim().isNotEmpty)
            'emergency_contact_phone': _emergencyPhoneCtrl.text.trim(),
          if (_emergencyRelCtrl.text.trim().isNotEmpty)
            'emergency_contact_relation': _emergencyRelCtrl.text.trim(),
        },
      };

      final ok = await _auth.authenticate(
        _emailCtrl.text.trim(),
        _passwordCtrl.text,
        register: true,
        remember: true,
        displayName: displayName,
        extraMetadata: extraMeta,
      );

      if (!mounted) return;

      if (_auth.notice != null) {
        await EmailVerificationDialog.show(
          context,
          email: _emailCtrl.text.trim(),
          onResend: () => _auth.resendConfirmation(_emailCtrl.text.trim()),
        );
        if (!mounted) return;
        Navigator.of(context).pop(_emailCtrl.text.trim());
        return;
      }

      if (ok) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const NearbyTestScreen()),
          (_) => false,
        );
        return;
      }

      setState(() => _error = _auth.error ?? 'สมัครไม่สำเร็จ กรุณาลองใหม่');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 20),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'เลือกวันเกิด',
      cancelText: 'ยกเลิก',
      confirmText: 'ตกลง',
    );
    if (picked != null && mounted) setState(() => _dob = picked);
  }

  InputDecoration _dec(String label, {IconData? icon, String? hint}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: TextStyle(
        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF939493),
        fontSize: 14,
      ),
      prefixIcon: icon != null
          ? Icon(
              icon,
              size: 21,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF85898A),
            )
          : null,
      filled: true,
      fillColor: isDark
          ? const Color(0xFF161C24)
          : Colors.white.withValues(alpha: 0.9),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF283442) : const Color(0xFFE3E1DE),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: _orange, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _sectionLabel(String text, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14, top: 6),
      child: Row(
        children: [
          Icon(icon, size: 19, color: _orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : _navy,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 0: Account ──
  Widget _buildStep0() => Form(
    key: _formKeys[0],
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionLabel('ข้อมูลบัญชี', Icons.account_circle_outlined),
        TextFormField(
          controller: _emailCtrl,
          enabled: !_busy,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          decoration: _dec('อีเมล *', icon: Icons.mail_outline_rounded),
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'กรุณากรอกอีเมล';
            if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim())) {
              return 'กรุณากรอกอีเมลที่ถูกต้อง';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _passwordCtrl,
          enabled: !_busy,
          obscureText: _passwordHidden,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.newPassword],
          decoration: _dec('รหัสผ่าน *', icon: Icons.lock_outline_rounded).copyWith(
            suffixIcon: IconButton(
              icon: Icon(
                _passwordHidden
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _passwordHidden = !_passwordHidden),
            ),
            helperText:
                'อย่างน้อย 8 ตัวอักษร มีตัวพิมพ์ใหญ่ พิมพ์เล็ก และอักขระพิเศษ (!@#\$&*~_.)',
            helperMaxLines: 2,
          ),
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: (v) {
            if (v == null || v.isEmpty) return 'กรุณากรอกรหัสผ่าน';
            if (v.length < 8) return 'ต้องมีอย่างน้อย 8 ตัวอักษร';
            if (!RegExp(r'[a-z]').hasMatch(v)) {
              return 'ต้องมีตัวพิมพ์เล็กอย่างน้อย 1 ตัว';
            }
            if (!RegExp(r'[A-Z]').hasMatch(v)) {
              return 'ต้องมีตัวพิมพ์ใหญ่อย่างน้อย 1 ตัว';
            }
            if (!RegExp(r'[!@#\$&*~_.]').hasMatch(v)) {
              return 'ต้องมีอักขระพิเศษอย่างน้อย 1 ตัว (!@#\$&*~_.)';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _confirmCtrl,
          enabled: !_busy,
          obscureText: _confirmHidden,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.done,
          decoration: _dec('ยืนยันรหัสผ่าน *', icon: Icons.lock_outline_rounded)
              .copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    _confirmHidden
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _confirmHidden = !_confirmHidden),
                ),
              ),
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: (v) {
            if (v == null || v.isEmpty) return 'กรุณายืนยันรหัสผ่าน';
            if (v != _passwordCtrl.text) {
              return 'รหัสผ่านทั้งสองช่องไม่ตรงกัน';
            }
            return null;
          },
        ),
      ],
    ),
  );

  // ── Step 1: Personal ──
  Widget _buildStep1() => Form(
    key: _formKeys[1],
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionLabel('ข้อมูลส่วนตัว', Icons.person_outline_rounded),
        TextFormField(
          controller: _fullNameCtrl,
          enabled: !_busy,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.name],
          maxLength: 200,
          decoration: _dec('ชื่อ-นามสกุล *', icon: Icons.badge_outlined),
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'กรุณากรอกชื่อ-นามสกุล' : null,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _displayNameCtrl,
          enabled: !_busy,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.nickname],
          maxLength: 100,
          decoration: _dec(
            'ชื่อที่แสดงใน RescueLink *',
            icon: Icons.person_outline,
            hint: 'ชื่อเล่น / นามเรียกขาน',
          ),
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'กรุณากรอกชื่อที่แสดง' : null,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _phoneCtrl,
          maxLength: 30,
          enabled: !_busy,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.telephoneNumber],
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s]')),
          ],
          decoration: _dec('เบอร์โทรศัพท์ (ถ้ามี)', icon: Icons.phone_outlined),
        ),
        const SizedBox(height: 14),
        _buildDobPicker(),
      ],
    ),
  );

  Widget _buildDobPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: _busy ? null : _pickDob,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF161C24)
              : Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: isDark ? const Color(0xFF283442) : const Color(0xFFE3E1DE),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 21,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF85898A),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _dob != null
                    ? '${_dob!.day}/${_dob!.month}/${_dob!.year}'
                    : 'วันเดือนปีเกิด (ถ้าทราบ)',
                style: TextStyle(
                  fontSize: 16,
                  color: _dob != null
                      ? (isDark ? const Color(0xFFF1F5F9) : _navy)
                      : (isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF939493)),
                ),
              ),
            ),
            if (_dob != null)
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => setState(() => _dob = null),
              ),
          ],
        ),
      ),
    );
  }

  // ── Step 2: Health & Emergency ──
  Widget _buildStep2() => Form(
    key: _formKeys[2],
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionLabel(
          'ข้อมูลสุขภาพฉุกเฉิน (ไม่บังคับ)',
          Icons.health_and_safety_outlined,
        ),
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFB37B)),
          ),
          child: const Text(
            '⚠️  ข้อมูลสุขภาพเป็นทางเลือก — สามารถกรอกภายหลังได้\n'
            'กรุ๊ปเลือดที่กรอกเองไม่สามารถใช้เป็นหลักฐานสำหรับการให้เลือด\n'
            'โดยไม่มีการตรวจยืนยันทางการแพทย์',
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: Color(0xFF7C4200),
            ),
          ),
        ),
        _buildBloodGroupChips(),
        const SizedBox(height: 14),
        _buildRhChips(),
        const SizedBox(height: 14),
        TextFormField(
          controller: _conditionsCtrl,
          maxLength: 2000,
          enabled: !_busy,
          maxLines: 2,
          textInputAction: TextInputAction.next,
          decoration: _dec(
            'โรคประจำตัว (ถ้ามี)',
            icon: Icons.medical_information_outlined,
            hint: 'เช่น เบาหวาน ความดันโลหิตสูง',
          ),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _allergiesCtrl,
          maxLength: 2000,
          enabled: !_busy,
          maxLines: 2,
          textInputAction: TextInputAction.next,
          decoration: _dec(
            'การแพ้ยา / อาหาร / สารอื่น (ถ้ามี)',
            icon: Icons.warning_amber_outlined,
            hint: 'เช่น แพ้เพนนิซิลิน แพ้อาหารทะเล',
          ),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _medicationsCtrl,
          maxLength: 2000,
          enabled: !_busy,
          maxLines: 2,
          textInputAction: TextInputAction.next,
          decoration: _dec(
            'ยาที่ใช้เป็นประจำ (ถ้ามี)',
            icon: Icons.medication_outlined,
          ),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _medNotesCtrl,
          maxLength: 2000,
          enabled: !_busy,
          maxLines: 2,
          textInputAction: TextInputAction.next,
          decoration: _dec(
            'ข้อควรระวังทางการแพทย์เพิ่มเติม',
            icon: Icons.note_alt_outlined,
          ),
        ),
        const SizedBox(height: 20),
        _sectionLabel('ผู้ติดต่อฉุกเฉิน (ถ้ามี)', Icons.contacts_outlined),
        TextFormField(
          controller: _emergencyNameCtrl,
          maxLength: 200,
          enabled: !_busy,
          textInputAction: TextInputAction.next,
          decoration: _dec(
            'ชื่อผู้ติดต่อฉุกเฉิน',
            icon: Icons.person_pin_outlined,
          ),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _emergencyPhoneCtrl,
          maxLength: 30,
          enabled: !_busy,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s]')),
          ],
          decoration: _dec(
            'เบอร์โทรผู้ติดต่อฉุกเฉิน',
            icon: Icons.phone_callback_outlined,
          ),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _emergencyRelCtrl,
          maxLength: 100,
          enabled: !_busy,
          textInputAction: TextInputAction.done,
          decoration: _dec(
            'ความสัมพันธ์กับผู้ติดต่อฉุกเฉิน',
            icon: Icons.family_restroom_outlined,
            hint: 'เช่น คู่สมรส พ่อแม่ ลูก',
          ),
        ),
        const SizedBox(height: 20),
        _buildConsentSection(),
      ],
    ),
  );

  Widget _buildBloodGroupChips() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final groups = ['ไม่ทราบ', 'A', 'B', 'AB', 'O'];
    return _chipGroup(
      label: 'กรุ๊ปเลือด',
      options: groups,
      selected: _bloodGroup,
      onSelect: (v) => setState(() => _bloodGroup = v),
      isDark: isDark,
    );
  }

  Widget _buildRhChips() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final opts = ['ไม่ทราบ', 'Positive (+)', 'Negative (-)'];
    return _chipGroup(
      label: 'Rh Factor',
      options: opts,
      selected: _rhFactor,
      onSelect: (v) => setState(() => _rhFactor = v),
      isDark: isDark,
    );
  }

  Widget _chipGroup({
    required String label,
    required List<String> options,
    required String selected,
    required void Function(String) onSelect,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF555F6D),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((o) {
            final sel = selected == o;
            return ChoiceChip(
              label: Text(o),
              selected: sel,
              onSelected: _busy ? null : (_) => onSelect(o),
              selectedColor: _orange,
              labelStyle: TextStyle(
                color: sel ? Colors.white : null,
                fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
              ),
              side: BorderSide(
                color: sel
                    ? _orange
                    : (isDark
                          ? const Color(0xFF283442)
                          : const Color(0xFFE3E1DE)),
              ),
              backgroundColor: isDark
                  ? const Color(0xFF1E2631)
                  : const Color(0xFFFAF9F7),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildConsentSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFFF1F5F9) : _navy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'การยินยอม',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        const SizedBox(height: 10),
        _consentRow(
          value: _consentTerms,
          onChanged: (v) => setState(() => _consentTerms = v!),
          text:
              'ฉันยอมรับข้อกำหนดการใช้งานและนโยบายความเป็นส่วนตัวของ RescueLink *',
          isDark: isDark,
        ),
        const SizedBox(height: 8),
        _consentRow(
          value: _consentHealth,
          onChanged: (v) => setState(() => _consentHealth = v!),
          text:
              'ฉันยินยอมให้ RescueLink จัดเก็บและใช้ข้อมูลสุขภาพฉุกเฉินของฉัน '
              'เพื่อจัดเตรียมข้อมูลสำหรับการช่วยเหลือ ตัวฉันเท่านั้นที่อ่านข้อมูลผ่านแอปได้ '
              'ระบบยังไม่มีการส่งข้อมูลสุขภาพให้ผู้ช่วยเหลือหรืออุปกรณ์ Nearby '
              'ฉันสามารถแก้ไข ถอนความยินยอม หรือลบข้อมูลได้ที่หน้าข้อมูลสมาชิก',
          isDark: isDark,
        ),
        TextButton(
          onPressed: () => showPrivacyNotice(context),
          child: const Text('อ่านข้อกำหนดและนโยบายความเป็นส่วนตัว'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF3D181C) : const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _error!,
              style: const TextStyle(color: Color(0xFFE04C4C), fontSize: 13),
            ),
          ),
        ],
      ],
    );
  }

  Widget _consentRow({
    required bool value,
    required ValueChanged<bool?> onChanged,
    required String text,
    required bool isDark,
  }) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Checkbox(
        value: value,
        activeColor: _orange,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        onChanged: _busy ? null : onChanged,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      const SizedBox(width: 6),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(top: 9),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF555F6D),
            ),
          ),
        ),
      ),
    ],
  );

  // ── Progress bar ──
  Widget _progressBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labels = ['บัญชี', 'ส่วนตัว', 'สุขภาพ'];
    return Row(
      children: List.generate(3, (i) {
        final active = i == _step;
        final done = i < _step;
        return Expanded(
          child: GestureDetector(
            onTap: (done && !_busy) ? () => setState(() => _step = i) : null,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: done
                        ? _orange
                        : active
                        ? _orange.withValues(alpha: 0.65)
                        : (isDark
                              ? const Color(0xFF283442)
                              : const Color(0xFFE3E1DE)),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: (active || done)
                        ? FontWeight.w700
                        : FontWeight.w400,
                    color: active
                        ? _orange
                        : done
                        ? _orange.withValues(alpha: 0.8)
                        : (isDark ? const Color(0xFF94A3B8) : Colors.grey),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  // ── Main build ──
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFFF1F5F9) : _navy;

    const stepTitles = [
      'สร้างบัญชี RescueLink',
      'ข้อมูลส่วนตัว',
      'ข้อมูลสุขภาพ & ผู้ติดต่อฉุกเฉิน',
    ];
    const stepSubs = [
      'ใช้อีเมลจริงที่เปิดอ่านได้ คุณต้องยืนยันอีเมลก่อนเข้าสู่ระบบ',
      'ชื่อที่แสดงจะปรากฏให้ผู้ใช้คนอื่นเห็นในระบบ',
      'ไม่บังคับ แก้ไขภายหลังได้ที่ข้อมูลสมาชิก ข้อมูลจะซิงก์หลังยืนยันอีเมลและเข้าสู่ระบบบนเครื่องนี้',
    ];

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0C1017)
          : const Color(0xFFFCF8F1),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color: isDark ? Colors.white : _navy,
          ),
          onPressed: _busy ? null : _back,
          tooltip: 'ย้อนกลับ',
        ),
        title: Text(
          'สมัครสมาชิก',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: _orange, onPrimary: Colors.white),
            textTheme: Theme.of(
              context,
            ).textTheme.apply(bodyColor: textColor, displayColor: textColor),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: _progressBar(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            stepTitles[_step],
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            stepSubs[_step],
                            style: TextStyle(
                              fontSize: 13.5,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF555F6D),
                            ),
                          ),
                          const SizedBox(height: 20),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: KeyedSubtree(
                              key: ValueKey(_step),
                              child: [
                                _buildStep0(),
                                _buildStep1(),
                                _buildStep2(),
                              ][_step],
                            ),
                          ),
                          const SizedBox(height: 24),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFCBA4), Color(0xFFFFB37B)],
                              ),
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: _navy,
                                shadowColor: Colors.transparent,
                                minimumSize: const Size.fromHeight(52),
                                shape: const StadiumBorder(),
                              ),
                              onPressed: _busy ? null : _next,
                              child: _busy
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : Text(
                                      _step < 2 ? 'ถัดไป  →' : 'สมัครสมาชิก',
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                          if (_step == 2) ...[
                            const SizedBox(height: 10),
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () {
                                      setState(() => _consentHealth = false);
                                      _next();
                                    },
                              style: TextButton.styleFrom(
                                foregroundColor: isDark
                                    ? const Color(0xFF94A3B8)
                                    : Colors.grey,
                              ),
                              child: const Text(
                                'ข้ามข้อมูลสุขภาพและสมัครทันที',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'มีบัญชีแล้ว? ',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : Colors.grey,
                                ),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  foregroundColor: _orange,
                                ),
                                onPressed: _busy
                                    ? null
                                    : () => Navigator.of(context).pop(),
                                child: const Text(
                                  'เข้าสู่ระบบ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
