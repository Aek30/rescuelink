import 'package:flutter/material.dart';
import 'nearby_test_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const navy = Color(0xFF102D43);
  static const orange = Color(0xFFFF6826);
  final form = GlobalKey<FormState>();
  final identity = TextEditingController();
  final password = TextEditingController();
  bool register = false, hidden = true, remember = true, english = false;
  String t(String th, String en) => english ? en : th;

  @override
  void dispose() {
    identity.dispose();
    password.dispose();
    super.dispose();
  }

  void notice() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        t('ระบบบัญชียังไม่พร้อมใช้งาน', 'Accounts are not available yet'),
      ),
      content: Text(
        t(
          'ยังไม่ได้เชื่อมต่อบริการยืนยันตัวตน คุณสามารถเข้าใช้งานแบบผู้เยี่ยมชมได้โดยไม่ต้องสมัครบัญชี',
          'Authentication is not connected yet. Please continue as a guest.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t('เข้าใจแล้ว', 'Got it')),
        ),
      ],
    ),
  );

  void submit() {
    if (form.currentState!.validate()) notice();
  }

  Widget field(bool secret) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: secret ? password : identity,
      obscureText: secret && hidden,
      autocorrect: false,
      enableSuggestions: !secret,
      keyboardType: secret
          ? TextInputType.visiblePassword
          : TextInputType.emailAddress,
      textInputAction: secret ? TextInputAction.done : TextInputAction.next,
      autofillHints: [
        secret
            ? (register ? AutofillHints.newPassword : AutofillHints.password)
            : AutofillHints.username,
      ],
      onFieldSubmitted: secret ? (_) => submit() : null,
      validator: (value) => value == null || value.trim().isEmpty
          ? t(
              secret ? 'กรุณากรอกรหัสผ่าน' : 'กรุณากรอกอีเมลหรือเบอร์โทรศัพท์',
              'This field is required',
            )
          : null,
      decoration: InputDecoration(
        hintText: secret
            ? t('รหัสผ่าน', 'Password')
            : t('อีเมลหรือเบอร์โทรศัพท์', 'Email or phone number'),
        hintStyle: TextStyle(
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF939493),
          fontSize: 14,
        ),
        prefixIcon: Icon(
          secret ? Icons.lock_outline_rounded : Icons.mail_outline_rounded,
          size: 21,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF85898A),
        ),
        suffixIcon: IconButton(
          tooltip: secret
              ? (hidden
                    ? t('แสดงรหัสผ่าน', 'Show password')
                    : t('ซ่อนรหัสผ่าน', 'Hide password'))
              : t('ล้างข้อมูล', 'Clear'),
          onPressed: secret
              ? () => setState(() => hidden = !hidden)
              : identity.clear,
          icon: Icon(
            secret
                ? (hidden
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined)
                : Icons.close_rounded,
            size: 20,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF969A9B),
          ),
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF161C24) : Colors.white.withValues(alpha: .9),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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

  Widget tab(bool value, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Semantics(
        selected: register == value,
        child: InkWell(
          onTap: () => setState(() {
            register = value;
            form.currentState?.reset();
            password.clear();
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: register == value ? orange : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: register == value
                    ? (isDark ? Colors.white : navy)
                    : (isDark ? const Color(0xFF94A3B8) : Colors.grey),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFFF1F5F9) : navy;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C1017) : const Color(0xFFFCF8F1),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - 40).clamp(0, double.infinity),
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
                      textTheme: Theme.of(
                        context,
                      ).textTheme.apply(bodyColor: textColor, displayColor: textColor),
                    ),
                    child: AutofillGroup(
                      child: Form(
                        key: form,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Align(
                              alignment: Alignment.centerRight,
                              child: PopupMenuButton<bool>(
                                tooltip: t('เลือกภาษา', 'Choose language'),
                                initialValue: english,
                                onSelected: (value) =>
                                    setState(() => english = value),
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: false, child: Text('ไทย')),
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
                            const SizedBox(height: 26),
                            Container(
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E2631) : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  tab(false, t('เข้าสู่ระบบ', 'Log in')),
                                  tab(true, t('สมัครใช้งาน', 'Sign up')),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            field(false),
                            const SizedBox(height: 12),
                            field(true),
                            Row(
                              children: [
                                Checkbox(
                                  value: remember,
                                  activeColor: orange,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  onChanged: (value) =>
                                      setState(() => remember = value!),
                                  visualDensity: VisualDensity.compact,
                                ),
                                Flexible(
                                  child: Text(
                                    t('จดจำฉัน', 'Remember me'),
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                                const Spacer(),
                                if (!register)
                                  TextButton(
                                    onPressed: notice,
                                    child: Text(
                                      t('ลืมรหัสผ่าน?', 'Forgot password?'),
                                      style: const TextStyle(
                                        color: Color(0xFFE85415),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
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
                                onPressed: submit,
                                child: Text(
                                  register
                                      ? t('สมัครใช้งาน', 'Create account')
                                      : t('เข้าสู่ระบบ', 'Log in'),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
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
                                    child: Text(t('หรือ', 'or')),
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
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                backgroundColor: isDark ? const Color(0xFF161C24) : Colors.white,
                                foregroundColor: textColor,
                                side: BorderSide(
                                  color: isDark
                                      ? const Color(0xFF283442)
                                      : const Color(0xFFE2E2E2),
                                ),
                                shape: const StadiumBorder(),
                                minimumSize: const Size.fromHeight(50),
                              ),
                              onPressed: notice,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'G',
                                    style: TextStyle(
                                      fontFamily: 'Roboto',
                                      color: Color(0xFF4285F4),
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Flexible(
                                    child: Text(
                                      t(
                                        'เข้าสู่ระบบด้วย Google',
                                        'Continue with Google',
                                      ),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            Material(
                              color: isDark ? const Color(0xFF161C24) : const Color(0xFFF0EBE3),
                              borderRadius: BorderRadius.circular(22),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(22),
                                onTap: () =>
                                    Navigator.of(context).pushReplacement(
                                      MaterialPageRoute<void>(
                                        builder: (_) => const NearbyTestScreen(),
                                      ),
                                    ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 16,
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: isDark
                                            ? const Color(0xFF382314)
                                            : const Color(0xFFFFEECF),
                                        foregroundColor: const Color(0xFFFF8A00),
                                        radius: 22,
                                        child: const Icon(
                                          Icons.person_rounded,
                                          size: 33,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              t(
                                                'เข้าใช้งานแบบผู้เยี่ยมชม (Guest)',
                                                'Continue as a guest',
                                              ),
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              t(
                                                'ใช้งานได้ทันที ไม่ต้องสมัครบัญชี',
                                                'Get started without an account',
                                              ),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isDark
                                                    ? const Color(0xFF94A3B8)
                                                    : const Color(0xFF858585),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        color: isDark
                                            ? const Color(0xFF94A3B8)
                                            : const Color(0xFF727778),
                                        size: 22,
                                      ),
                                    ],
                                  ),
                                ),
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
