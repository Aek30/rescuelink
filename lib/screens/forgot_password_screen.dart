import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

enum _ResetStep { requestOtp, verifyAndReset }

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.auth, this.initialEmail});

  final AuthService? auth;
  final String? initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static const navy = Color(0xFF102D43);
  static const orange = Color(0xFFFF6826);

  final _requestFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  _ResetStep _currentStep = _ResetStep.requestOtp;
  bool _busy = false;
  bool _hiddenPassword = true;
  bool _hiddenConfirm = true;
  bool _english = false;
  String? _error;
  String? _successMessage;

  AuthService get auth => widget.auth ?? AuthService.instance;
  String t(String th, String en) => _english ? en : th;

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null && widget.initialEmail!.isNotEmpty) {
      _emailController.text = widget.initialEmail!;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleSendOtp() async {
    if (_busy || !_requestFormKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _successMessage = null;
    });

    final email = _emailController.text.trim();
    try {
      await auth.sendPasswordResetEmail(email).timeout(const Duration(seconds: 20));
      if (!mounted) return;
      setState(() {
        _currentStep = _ResetStep.verifyAndReset;
        _successMessage = t(
          'ส่งรหัสยืนยัน 6 หลักไปยังอีเมลของคุณแล้ว',
          'Verification code has been sent to your email',
        );
      });
    } on AuthException catch (e) {
      setState(() {
        _error = switch (e.code) {
          'over_email_send_rate_limit' || 'over_request_rate_limit' => t(
              'ส่งคำขอบ่อยเกินไป กรุณารอสักครู่แล้วลองใหม่',
              'Too many requests. Please wait a moment and try again.',
            ),
          'user_not_found' => t(
              'ไม่พบบัญชีที่ใช้อีเมลนี้ในระบบ',
              'No account found with this email',
            ),
          _ => t(
              'ไม่สามารถส่งรหัสยืนยันได้ กรุณาตรวจอีเมลแล้วลองใหม่',
              'Could not send verification code. Please check your email.',
            ),
        };
      });
    } on SocketException {
      setState(() {
        _error = t(
          'เชื่อมต่ออินเทอร์เน็ตไม่ได้ กรุณาตรวจสอบการเชื่อมต่อ',
          'Cannot connect to the internet. Please check your network.',
        );
      });
    } on TimeoutException {
      setState(() {
        _error = t(
          'การเชื่อมต่อหมดเวลา กรุณาลองใหม่อีกครั้ง',
          'Connection timed out. Please try again.',
        );
      });
    } catch (_) {
      setState(() {
        _error = t(
          'เกิดข้อผิดพลาดในการส่งรหัส กรุณาลองใหม่อีกครั้ง',
          'Failed to send code. Please try again.',
        );
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleResetPassword() async {
    if (_busy || !_resetFormKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _successMessage = null;
    });

    final email = _emailController.text.trim();
    final token = _otpController.text.trim();
    final newPassword = _passwordController.text;

    try {
      await auth
          .resetPasswordWithOtp(
            email: email,
            token: token,
            newPassword: newPassword,
          )
          .timeout(const Duration(seconds: 25));

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => PopScope(
          canPop: false,
          child: AlertDialog(
            icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 48),
            title: Text(t('ตั้งรหัสผ่านใหม่สำเร็จ', 'Password Reset Successful')),
            content: Text(
              t(
                'คุณสามารถเข้าสู่ระบบด้วยรหัสผ่านใหม่ได้ทันที',
                'You can now sign in with your new password.',
              ),
            ),
            actions: [
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: orange),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  Navigator.of(context).pop(_emailController.text.trim());
                },
                child: Text(t('กลับไปหน้าเข้าสู่ระบบ', 'Back to login')),
              ),
            ],
          ),
        ),
      );
    } on AuthException catch (e) {
      setState(() {
        _error = switch (e.code) {
          'otp_expired' => t('รหัสยืนยันหมดอายุแล้ว กรุณากดส่งรหัสใหม่', 'Code expired. Please request a new code.'),
          'weak_password' => t('รหัสผ่านไม่ผ่านเกณฑ์ความปลอดภัย', 'Password is too weak'),
          _ => t('รหัสยืนยันไม่ถูกต้อง หรือหมดอายุแล้ว', 'Invalid or expired verification code'),
        };
      });
    } on SocketException {
      setState(() {
        _error = t(
          'เชื่อมต่ออินเทอร์เน็ตไม่ได้ กรุณาตรวจสอบการเชื่อมต่อ',
          'Cannot connect to the internet. Please check your network.',
        );
      });
    } on TimeoutException {
      setState(() {
        _error = t(
          'การเชื่อมต่อหมดเวลา กรุณาลองใหม่อีกครั้ง',
          'Connection timed out. Please try again.',
        );
      });
    } catch (_) {
      setState(() {
        _error = t(
          'ตั้งรหัสผ่านใหม่ไม่สำเร็จ ตรวจสอบรหัสยืนยันแล้วลองใหม่',
          'Failed to reset password. Please verify your code and try again.',
        );
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return t('กรุณากรอกรหัสผ่านใหม่', 'Please enter a new password');
    }
    if (value.length < 8) {
      return t('รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษร', 'Use at least 8 characters');
    }
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return t('ต้องมีตัวพิมพ์เล็กอย่างน้อย 1 ตัว', 'Must contain at least one lowercase letter');
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return t('ต้องมีตัวพิมพ์ใหญ่อย่างน้อย 1 ตัว', 'Must contain at least one uppercase letter');
    }
    if (!RegExp(r'[!@#\$&*~_.]').hasMatch(value)) {
      return t('ต้องมีอักขระพิเศษอย่างน้อย 1 ตัว (!@#\$&*~_.)', 'Must contain at least one special character');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFFF1F5F9) : navy;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C1017) : const Color(0xFFFCF8F1),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          tooltip: t('ย้อนกลับ', 'Back'),
        ),
        actions: [
          PopupMenuButton<bool>(
            tooltip: t('เลือกภาษา', 'Choose language'),
            initialValue: _english,
            onSelected: (value) => setState(() => _english = value),
            itemBuilder: (_) => const [
              PopupMenuItem(value: false, child: Text('ไทย')),
              PopupMenuItem(value: true, child: Text('English')),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_english ? 'English' : 'ไทย', style: TextStyle(color: textColor)),
                  const SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: textColor),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: orange.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_reset_rounded,
                        color: orange,
                        size: 46,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    t('ลืมรหัสผ่าน', 'Forgot Password'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currentStep == _ResetStep.requestOtp
                        ? t(
                            'กรอกอีเมลของคุณเพื่อรับรหัสยืนยัน (OTP) สำหรับตั้งรหัสผ่านใหม่',
                            'Enter your email to receive a verification code (OTP) to reset your password.',
                          )
                        : t(
                            'กรอกรหัสยืนยัน 6 หลักที่ได้รับในอีเมล พร้อมตั้งรหัสผ่านใหม่',
                            'Enter the 6-digit code received in your email and create a new password.',
                          ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(color: Colors.red, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (_successMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _successMessage!,
                              style: const TextStyle(color: Colors.green, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (_currentStep == _ResetStep.requestOtp)
                    _buildRequestOtpForm(isDark)
                  else
                    _buildVerifyAndResetForm(isDark),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequestOtpForm(bool isDark) {
    return Form(
      key: _requestFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _emailController,
            enabled: !_busy,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return t('กรุณากรอกอีเมล', 'Email is required');
              }
              if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())) {
                return t('กรุณากรอกอีเมลที่ถูกต้อง', 'Enter a valid email');
              }
              return null;
            },
            decoration: InputDecoration(
              labelText: t('อีเมลที่ลงทะเบียน', 'Registered email'),
              hintText: 'example@email.com',
              prefixIcon: const Icon(Icons.mail_outline_rounded, size: 21),
              filled: true,
              fillColor: isDark ? const Color(0xFF161C24) : Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: BorderSide(
                  color: isDark ? const Color(0xFF283442) : const Color(0xFFE3E1DE),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: orange, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 24),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF7C30), Color(0xFFFF6024)],
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                minimumSize: const Size.fromHeight(50),
                shape: const StadiumBorder(),
              ),
              onPressed: _busy ? null : _handleSendOtp,
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      t('ส่งรหัสยืนยัน', 'Send verification code'),
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: Text(
              t('จำรหัสผ่านได้แล้ว? เข้าสู่ระบบ', 'Remember password? Log in'),
              style: const TextStyle(color: orange, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifyAndResetForm(bool isDark) {
    return Form(
      key: _resetFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2631) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.email_outlined, size: 20, color: orange),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _emailController.text.trim(),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _currentStep = _ResetStep.requestOtp;
                            _error = null;
                            _successMessage = null;
                          }),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Text(t('เปลี่ยน', 'Change'), style: const TextStyle(color: orange)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _otpController,
            enabled: !_busy,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (value) => (value == null || value.trim().isEmpty)
                ? t(
                    'กรุณากรอกรหัสหรือวางลิงก์จากอีเมล',
                    'Enter code or paste link from email',
                  )
                : null,
            decoration: InputDecoration(
              labelText: t(
                'รหัสยืนยัน หรือ วางลิงก์ Reset password',
                'Code or Paste Reset Password Link',
              ),
              hintText: t(
                'ใส่รหัส 6 หลัก หรือ วางลิงก์จากอีเมล',
                'Enter 6-digit code or paste link from email',
              ),
              helperText: t(
                'คัดลอกลิงก์ Reset password จากอีเมลมาวางที่นี่ได้เลย',
                'You can copy the Reset password link from email and paste here',
              ),
              prefixIcon: const Icon(Icons.link_rounded, size: 21),
              filled: true,
              fillColor: isDark ? const Color(0xFF161C24) : Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: BorderSide(
                  color: isDark ? const Color(0xFF283442) : const Color(0xFFE3E1DE),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: orange, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _passwordController,
            enabled: !_busy,
            obscureText: _hiddenPassword,
            autocorrect: false,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: _validatePassword,
            decoration: InputDecoration(
              labelText: t('รหัสผ่านใหม่', 'New password'),
              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 21),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _hiddenPassword = !_hiddenPassword),
                icon: Icon(
                  _hiddenPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 20,
                ),
              ),
              filled: true,
              fillColor: isDark ? const Color(0xFF161C24) : Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: BorderSide(
                  color: isDark ? const Color(0xFF283442) : const Color(0xFFE3E1DE),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: orange, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _confirmController,
            enabled: !_busy,
            obscureText: _hiddenConfirm,
            autocorrect: false,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return t('กรุณายืนยันรหัสผ่านใหม่', 'Confirm your new password');
              }
              if (value != _passwordController.text) {
                return t('รหัสผ่านทั้งสองช่องไม่ตรงกัน', 'Passwords do not match');
              }
              return null;
            },
            decoration: InputDecoration(
              labelText: t('ยืนยันรหัสผ่านใหม่', 'Confirm new password'),
              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 21),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _hiddenConfirm = !_hiddenConfirm),
                icon: Icon(
                  _hiddenConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 20,
                ),
              ),
              filled: true,
              fillColor: isDark ? const Color(0xFF161C24) : Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: BorderSide(
                  color: isDark ? const Color(0xFF283442) : const Color(0xFFE3E1DE),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: orange, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 24),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF7C30), Color(0xFFFF6024)],
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                minimumSize: const Size.fromHeight(50),
                shape: const StadiumBorder(),
              ),
              onPressed: _busy ? null : _handleResetPassword,
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      t('บันทึกรหัสผ่านใหม่', 'Save new password'),
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                t('ไม่ได้รับรหัส? ', "Didn't receive code? "),
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              TextButton(
                onPressed: _busy ? null : _handleSendOtp,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  t('ส่งรหัสอีกครั้ง', 'Resend code'),
                  style: const TextStyle(
                    color: orange,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
