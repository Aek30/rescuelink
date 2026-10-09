import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/member_service.dart';
import 'login_screen.dart';
import 'chat_history_screen.dart';
import 'emergency_profile_screen.dart';

class MemberScreen extends StatefulWidget {
  const MemberScreen({super.key, this.repository, this.beforeExit});
  final MemberRepository? repository;
  final Future<void> Function()? beforeExit;
  @override
  State<MemberScreen> createState() => _MemberScreenState();
}

class _MemberScreenState extends State<MemberScreen> {
  late final MemberRepository repository;
  final name = TextEditingController();
  final form = GlobalKey<FormState>();
  MemberProfile? profile;
  bool busy = false;
  String? error, notice;

  @override
  void initState() {
    super.initState();
    repository =
        widget.repository ?? SupabaseMemberRepository(AuthService.instance);
    _load();
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      await action().timeout(const Duration(seconds: 45));
    } catch (e) {
      if (mounted) setState(() => error = memberError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _load() => _run(() async {
    final value = await repository.read();
    if (!mounted) return;
    setState(() {
      profile = value;
      name.text = value.name;
    });
  });

  Future<void> _save() async {
    if (!form.currentState!.validate()) return;
    await _run(() async {
      final value = await repository.updateName(name.text);
      if (mounted) {
        setState(() {
          profile = value;
          name.text = value.name;
          notice = 'บันทึกข้อมูลสมาชิกบน Supabase แล้ว';
        });
      }
    });
  }

  void _login() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _delete() async {
    final password = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบบัญชีถาวร'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'บัญชี โปรไฟล์ ข้อมูลบน Cloud และฐานข้อมูลของบัญชีนี้ในเครื่องจะถูกลบ ไม่สามารถย้อนกลับได้\nกรอกรหัสผ่านปัจจุบันเพื่อยืนยัน',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: password,
                obscureText: true,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'รหัสผ่านปัจจุบัน',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ยืนยันลบบัญชี'),
          ),
        ],
      ),
    );
    final value = password.text;
    await Future<void>.delayed(const Duration(milliseconds: 300));
    password.dispose();
    if (accepted != true || !mounted) return;
    await _run(() async {
      await widget.beforeExit?.call();
      await repository.deleteAccount(value);
      _login();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('ข้อมูลสมาชิก'),
      actions: [
        IconButton(
          tooltip: 'ประวัติข้อความ / Cloud',
          onPressed: () => Navigator.push<void>(
            context,
            MaterialPageRoute(builder: (_) => const ChatHistoryScreen()),
          ),
          icon: const Icon(Icons.cloud_outlined),
        ),
        IconButton(
          tooltip: 'โหลดข้อมูลจาก Supabase',
          onPressed: busy ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'บัญชี RescueLink',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            const Text('ข้อมูลสมาชิกอ่านและบันทึกกับ Supabase โดยตรง'),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EmergencyProfileScreen(),
                      ),
                    ),
              icon: const Icon(Icons.medical_information_outlined),
              label: const Text('ข้อมูลส่วนตัวและสุขภาพฉุกเฉิน'),
            ),
            if (busy) const LinearProgressIndicator(),
            if (error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (notice != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(notice!),
              ),
            if (profile != null) ...[
              const SizedBox(height: 24),
              Text('อีเมล: ${profile!.email}'),
              const SizedBox(height: 8),
              SelectableText('User UID: ${profile!.id}'),
              const SizedBox(height: 24),
              Form(
                key: form,
                child: TextFormField(
                  controller: name,
                  enabled: !busy,
                  maxLength: 100,
                  decoration: const InputDecoration(labelText: 'ชื่อสมาชิก'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'กรุณาระบุชื่อสมาชิก'
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: busy ? null : _save,
                icon: const Icon(Icons.save),
                label: const Text('บันทึกข้อมูลสมาชิก'),
              ),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: busy ? null : _delete,
                icon: const Icon(Icons.delete_forever),
                label: const Text('ลบบัญชีถาวร'),
              ),
            ],
            const SizedBox(height: 16),
            TextButton(
              onPressed: busy
                  ? null
                  : () => _run(() async {
                      await widget.beforeExit?.call();
                      await AuthService.instance.signOut();
                      _login();
                    }),
              child: const Text('ออกจากระบบ'),
            ),
          ],
        ),
      ),
    ),
  );
}
