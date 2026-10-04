import 'package:flutter/material.dart';
import 'nearby_test_screen.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.auth});
  final AuthService? auth;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const navy = Color(0xFF102D43);
  static const orange = Color(0xFFFF6826);
  final form = GlobalKey<FormState>();
  final identity = TextEditingController();
  final password = TextEditingController();
  final displayName = TextEditingController();
  final confirmation = TextEditingController();
  bool register = false, hidden = true, remember = true, english = false;
  bool busy = false, claimGuest = false;
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
    displayName.dispose();
    confirmation.dispose();
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
      register: register,
      remember: remember,
      claimGuest: claimGuest,
      displayName: displayName.text,
    );
    if (!mounted) return;
    setState(() {
      busy = auth.notice != null;
      error = auth.error;
      notice = auth.notice;
    });
    if (notice != null) {
      FocusScope.of(context).unfocus();
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => PopScope(
          canPop: false,
          child: AlertDialog(
            scrollable: true,
            icon: const Icon(
              Icons.mark_email_unread_outlined,
              color: orange,
              size: 40,
            ),
            title: Text(t('กรุณายืนยันอีเมลก่อน', 'Verify your email first')),
            content: Text(
              t(
                'เปิดกล่องจดหมายของ ${identity.text.trim()} แล้วกดลิงก์ยืนยันบัญชีก่อนเข้าสู่ระบบ\n\nหากไม่พบอีเมล ให้ตรวจโฟลเดอร์สแปม หากเคยยืนยันบัญชีนี้แล้ว สามารถเข้าสู่ระบบได้เลย',
                'Open the inbox for ${identity.text.trim()} and follow the confirmation link before logging in.\n\nCheck spam if the email is missing. If this account is already verified, you can log in.',
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(t('ไปหน้าเข้าสู่ระบบ', 'Go to login')),
              ),
            ],
          ),
        ),
      );
      if (!mounted) return;
      setState(() {
        busy = false;
        register = false;
        password.clear();
        confirmation.clear();
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

  Widget field(bool secret) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: secret ? password : identity,
      enabled: !busy,
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
              secret ? 'กรุณากรอกรหัสผ่าน' : 'กรุณากรอกอีเมล',
              'This field is required',
            )
          : !secret &&
                !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())
          ? t('กรุณากรอกอีเมลที่ถูกต้อง', 'Enter a valid email')
          : secret && register && value.length < 8
          ? t('รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษร', 'Use at least 8 characters')
          : null,
      decoration: InputDecoration(
        labelText: secret ? t('รหัสผ่าน', 'Password') : t('อีเมล', 'Email'),
        hintText: secret ? t('รหัสผ่าน', 'Password') : t('อีเมล', 'Email'),
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

  Widget tab(bool value, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Semantics(
        selected: register == value,
        child: InkWell(
          onTap: busy
              ? null
              : () => setState(() {
                  register = value;
                  form.currentState?.reset();
                  password.clear();
                  confirmation.clear();
                  error = null;
                  notice = null;
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
                                color: isDark
                                    ? const Color(0xFF1E2631)
                                    : Colors.white,
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
                            if (register) ...[
                              Text(
                                t(
                                  'สร้างบัญชี RescueLink',
                                  'Create your RescueLink account',
                                ),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                t(
                                  'ใช้อีเมลจริงที่เปิดอ่านได้ คุณต้องยืนยันอีเมลก่อนเข้าสู่ระบบ',
                                  'Use an email you can access. Verify it before logging in.',
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                key: const ValueKey('signup-name'),
                                controller: displayName,
                                enabled: !busy,
                                maxLength: 100,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.nickname],
                                decoration: InputDecoration(
                                  labelText: t('ชื่อที่แสดง', 'Display name'),
                                  helperText: t(
                                    'ชื่อหรือนามเรียกขานที่ต้องการใช้',
                                    'Your name or preferred nickname',
                                  ),
                                  prefixIcon: const Icon(Icons.person_outline),
                                  border: const OutlineInputBorder(),
                                ),
                                validator: (value) =>
                                    (value?.trim().isEmpty ?? true)
                                    ? t(
                                        'กรุณากรอกชื่อที่แสดง',
                                        'Enter a display name',
                                      )
                                    : null,
                              ),
                              const SizedBox(height: 12),
                            ],
                            field(false),
                            const SizedBox(height: 12),
                            field(true),
                            if (register) ...[
                              const SizedBox(height: 12),
                              TextFormField(
                                key: const ValueKey('signup-confirmation'),
                                controller: confirmation,
                                enabled: !busy,
                                obscureText: hidden,
                                autocorrect: false,
                                enableSuggestions: false,
                                autofillHints: const [
                                  AutofillHints.newPassword,
                                ],
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => submit(),
                                decoration: InputDecoration(
                                  labelText: t(
                                    'ยืนยันรหัสผ่าน',
                                    'Confirm password',
                                  ),
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  border: const OutlineInputBorder(),
                                ),
                                validator: (value) =>
                                    value == null || value.isEmpty
                                    ? t(
                                        'กรุณายืนยันรหัสผ่าน',
                                        'Confirm your password',
                                      )
                                    : value != password.text
                                    ? t(
                                        'รหัสผ่านทั้งสองช่องไม่ตรงกัน',
                                        'Passwords do not match',
                                      )
                                    : null,
                              ),
                            ],
                            CheckboxListTile(
                              value: claimGuest,
                              onChanged: busy
                                  ? null
                                  : (value) =>
                                        setState(() => claimGuest = value!),
                              title: Text(
                                t(
                                  'ผูกข้อมูล Guest เดิมกับบัญชีนี้',
                                  'Move guest data to this account',
                                ),
                              ),
                              subtitle: Text(
                                t(
                                  'ย้ายประวัติ SOS และคิวส่งทั้งหมด ใช้ได้เมื่อบัญชียังไม่มีข้อมูลในเครื่องนี้',
                                  'Moves history, SOS and outbox; available before this account has local data',
                                ),
                              ),
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                            if (error != null)
                              Text(
                                error!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
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
                            Row(
                              children: [
                                Checkbox(
                                  value: remember,
                                  activeColor: orange,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  onChanged: busy
                                      ? null
                                      : (value) =>
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
                              ],
                            ),
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
                                  minimumSize: const Size.fromHeight(50),
                                  shape: const StadiumBorder(),
                                ),
                                onPressed: busy ? null : submit,
                                child: Text(
                                  busy
                                      ? t('กำลังดำเนินการ…', 'Please wait…')
                                      : register
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
                            const SizedBox(height: 18),
                            Material(
                              color: isDark
                                  ? const Color(0xFF161C24)
                                  : const Color(0xFFF0EBE3),
                              borderRadius: BorderRadius.circular(22),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(22),
                                onTap: busy
                                    ? null
                                    : () =>
                                          Navigator.of(context).pushReplacement(
                                            MaterialPageRoute<void>(
                                              builder: (_) =>
                                                  const NearbyTestScreen(),
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
                                        foregroundColor: const Color(
                                          0xFFFF8A00,
                                        ),
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
