import 'package:flutter/material.dart';
import 'nearby_test_screen.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.auth});
  final AuthService? auth;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const navy = Color(0xFF102D43);
  static const orange = Color(0xFFFFB37B);
  final form = GlobalKey<FormState>();
  final identity = TextEditingController();
  final password = TextEditingController();
  bool hidden = true, english = false;
  bool busy = false;
  String? error;
  String? notice;
  AuthService get auth => widget.auth ?? AuthService.instance;
  String t(String th, String en) => english ? en : th;

  @override
  void initState() {
    super.initState();
    error = auth.error;
  }

  @override
  void dispose() {
    identity.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    final ok = await auth.authenticate(
      identity.text,
      password.text,
      register: false,
      remember: true,
    );
    if (!mounted) return;
    setState(() {
      busy = auth.notice != null;
      error = auth.error;
      notice = auth.notice;
    });
    if (notice != null) {
      FocusScope.of(context).unfocus();
      // Show the new email verification dialog
      await EmailVerificationDialog.show(
        context,
        email: identity.text.trim(),
        onResend: () => auth.resendConfirmation(identity.text.trim()),
      );
      if (!mounted) return;
      setState(() {
        busy = false;
        password.clear();
      });
    }
    if (ok) {
      password.clear();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const NearbyTestScreen()),
        (_) => false,
      );
    }
  }

  Future<void> _openForgotPassword() async {
    final updatedEmail = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => ForgotPasswordScreen(
          auth: auth,
          initialEmail: identity.text.trim(),
        ),
      ),
    );
    if (updatedEmail != null && updatedEmail.isNotEmpty && mounted) {
      setState(() {
        identity.text = updatedEmail;
        password.clear();
        error = null;
        notice = t(
          'ตั้งรหัสผ่านใหม่เรียบร้อย กรุณาเข้าสู่ระบบด้วยรหัสผ่านใหม่',
          'Password updated. Please log in with your new password.',
        );
      });
    }
  }

  void _openRegister() {
    Navigator.of(context)
        .push<String>(
          MaterialPageRoute<String>(builder: (_) => RegisterScreen(auth: auth)),
        )
        .then((email) {
          if (mounted && email != null) {
            setState(() {
              identity.text = email;
              password.clear();
            });
          }
        });
  }

  Widget _emailField() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: identity,
      enabled: !busy,
      autocorrect: false,
      enableSuggestions: true,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.username],
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return t('กรุณากรอกอีเมล', 'This field is required');
        }
        if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())) {
          return t('กรุณากรอกอีเมลที่ถูกต้อง', 'Enter a valid email');
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: t('อีเมล', 'Email'),
        hintText: t('กรอกอีเมลของคุณ', 'Enter your email'),
        hintStyle: TextStyle(
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF939493),
          fontSize: 14,
        ),
        prefixIcon: Icon(
          Icons.mail_outline_rounded,
          size: 21,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF85898A),
        ),
        suffixIcon: IconButton(
          tooltip: t('ล้างข้อมูล', 'Clear'),
          onPressed: identity.clear,
          icon: Icon(
            Icons.close_rounded,
            size: 20,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF969A9B),
          ),
        ),
        filled: true,
        fillColor: isDark
            ? const Color(0xFF161C24)
            : Colors.white.withValues(alpha: .9),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
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
    );
  }

  Widget _passwordField() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: password,
      enabled: !busy,
      obscureText: hidden,
      autocorrect: false,
      enableSuggestions: false,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.password],
      onFieldSubmitted: (_) => submit(),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return t('กรุณากรอกรหัสผ่าน', 'This field is required');
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: t('รหัสผ่าน', 'Password'),
        hintText: t('กรอกรหัสผ่าน', 'Enter your password'),
        hintStyle: TextStyle(
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF939493),
          fontSize: 14,
        ),
        prefixIcon: Icon(
          Icons.lock_outline_rounded,
          size: 21,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF85898A),
        ),
        suffixIcon: IconButton(
          tooltip: hidden
              ? t('แสดงรหัสผ่าน', 'Show password')
              : t('ซ่อนรหัสผ่าน', 'Hide password'),
          onPressed: () => setState(() => hidden = !hidden),
          icon: Icon(
            hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 20,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF969A9B),
          ),
        ),
        filled: true,
        fillColor: isDark
            ? const Color(0xFF161C24)
            : Colors.white.withValues(alpha: .9),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFFF1F5F9) : navy;
    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0C1017)
          : const Color(0xFFFCF8F1),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - 40).clamp(
                  0,
                  double.infinity,
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 390),
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: Theme.of(context).colorScheme.copyWith(
                        primary: orange,
                        onPrimary: Colors.white,
                      ),
                      textTheme: Theme.of(context).textTheme.apply(
                        bodyColor: textColor,
                        displayColor: textColor,
                      ),
                    ),
                    child: AutofillGroup(
                      child: Form(
                        key: form,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Language picker
                            Align(
                              alignment: Alignment.centerRight,
                              child: PopupMenuButton<bool>(
                                tooltip: t('เลือกภาษา', 'Choose language'),
                                initialValue: english,
                                onSelected: (value) =>
                                    setState(() => english = value),
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: false,
                                    child: Text('ไทย'),
                                  ),
                                  PopupMenuItem(
                                    value: true,
                                    child: Text('English'),
                                  ),
                                ],
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(english ? 'English' : 'ไทย'),
                                      const SizedBox(width: 6),
                                      const Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            // Logo
                            Center(
                              child: Image.asset(
                                isDark
                                    ? 'assets/branding/rescuelink-logo-dark.png'
                                    : 'assets/branding/rescuelink-logo.png',
                                width: 114,
                                height: 114,
                                semanticLabel: 'RescueLink',
                              ),
                            ),
                            Center(
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'Rescue',
                                      style: TextStyle(color: textColor),
                                    ),
                                    const TextSpan(
                                      text: 'Link',
                                      style: TextStyle(color: orange),
                                    ),
                                  ],
                                ),
                                style: const TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 38,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1.8,
                                  height: 1.1,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              t(
                                'เชื่อมต่อผู้คน ในทุกสถานการณ์',
                                'Connecting people in every situation',
                              ),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 28),
                            // Section title
                            Text(
                              t('เข้าสู่ระบบ', 'Sign in'),
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              t(
                                'เข้าสู่ระบบด้วยบัญชี RescueLink ของคุณ',
                                'Sign in to your RescueLink account',
                              ),
                              style: TextStyle(
                                fontSize: 13.5,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF555F6D),
                              ),
                            ),
                            const SizedBox(height: 20),
                            _emailField(),
                            const SizedBox(height: 14),
                            _passwordField(),
                            const SizedBox(height: 10),
                            // Session stays in secure storage for off-grid startup.
                            Row(
                              children: [
                                const Spacer(),
                                TextButton(
                                  key: const ValueKey('forgot-password-button'),
                                  onPressed: busy ? null : _openForgotPassword,
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    t('ลืมรหัสผ่าน?', 'Forgot password?'),
                                    style: const TextStyle(
                                      color: orange,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            // Error / notice
                            if (error != null)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 8,
                                  bottom: 4,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF3D181C)
                                        : const Color(0xFFFFEBEE),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    error!,
                                    style: const TextStyle(
                                      color: Color(0xFFE04C4C),
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            if (notice != null)
                              Semantics(
                                liveRegion: true,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  child: Text(
                                    notice!,
                                    style: TextStyle(color: textColor),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 14),
                            // Login button
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFF7C30),
                                    Color(0xFFFF6024),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(28),
                              ),
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  shadowColor: Colors.transparent,
                                  minimumSize: const Size.fromHeight(52),
                                  shape: const StadiumBorder(),
                                ),
                                onPressed: busy ? null : submit,
                                child: busy
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : Text(
                                        t('เข้าสู่ระบบ', 'Log in'),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            // Divider
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Divider(
                                      color: isDark
                                          ? const Color(0xFF283442)
                                          : const Color(0xFFDEDCD8),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Text(
                                      t('ยังไม่มีบัญชี?', 'No account yet?'),
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark
                                            ? const Color(0xFF94A3B8)
                                            : Colors.grey,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(
                                      color: isDark
                                          ? const Color(0xFF283442)
                                          : const Color(0xFFDEDCD8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            // Register button
                            OutlinedButton.icon(
                              key: const ValueKey('register-button'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: orange,
                                side: const BorderSide(
                                  color: orange,
                                  width: 1.5,
                                ),
                                minimumSize: const Size.fromHeight(50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                              ),
                              onPressed: busy ? null : _openRegister,
                              icon: const Icon(Icons.person_add_outlined),
                              label: Text(
                                t('สมัครสมาชิก RescueLink', 'Create account'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Info about offline mode
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF161C24)
                                    : const Color(0xFFF0EBE3),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF283442)
                                      : const Color(0xFFE3E1DE),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.wifi_off_rounded,
                                    size: 18,
                                    color: isDark
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF555F6D),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      t(
                                        'ต้องมีอินเทอร์เน็ตเพื่อสมัครและเข้าสู่ระบบครั้งแรกบนเครื่องนี้ '
                                            'หลังจากนั้น '
                                            'คุณสามารถใช้ SOS และสื่อสารผ่าน Nearby ได้โดยไม่ต้องมีอินเทอร์เน็ต',
                                        'After your first sign-in, you can use SOS and Nearby messaging without internet.',
                                      ),
                                      style: TextStyle(
                                        fontSize: 12,
                                        height: 1.5,
                                        color: isDark
                                            ? const Color(0xFF94A3B8)
                                            : const Color(0xFF555F6D),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
