import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/member_service.dart';
import '../services/local_database_service.dart';
import '../services/app_preferences.dart';
import '../services/sos_sync_service.dart';
import '../theme/rescue_theme.dart';
import '../widgets/rescue_ui.dart';
import 'login_screen.dart';
import 'chat_history_screen.dart';
import 'emergency_profile_screen.dart';
import 'sync_screen.dart';

class MemberScreen extends StatefulWidget {
  const MemberScreen({super.key, this.repository, this.beforeExit});
  final MemberRepository? repository;
  final Future<void> Function()? beforeExit;
  @override
  State<MemberScreen> createState() => _MemberScreenState();
}

class _MemberScreenState extends State<MemberScreen> {
  String t(String key) => AppPreferences.instance.text(key);
  late final MemberRepository repository;
  final name = TextEditingController();
  final form = GlobalKey<FormState>();
  MemberProfile? profile;
  bool busy = false;
  String? error, notice;
  RescueBannerKind noticeKind = RescueBannerKind.info;

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
      noticeKind = RescueBannerKind.info;
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
    if (widget.repository == null) {
      final session = AuthService.instance.session;
      if (session != null) {
        final cached =
            await LocalDatabaseService.instance.getSetting(
              'profileNameDraft',
            ) ??
            await LocalDatabaseService.instance.getSetting(
              'profileDisplayName',
            );
        if (!mounted) return;
        setState(() {
          profile = MemberProfile(
            id: session.userId,
            email: session.email,
            name: cached ?? '',
          );
          name.text = cached ?? '';
        });
      }
    }
    final value = await repository.read();
    if (!mounted) return;
    final draft = widget.repository == null
        ? await LocalDatabaseService.instance.getSetting('profileNameDraft')
        : null;
    if (!mounted) return;
    setState(() {
      profile = value;
      name.text = draft ?? value.name;
      if (draft != null) {
        notice = t(
          "ชื่อในเครื่องยังไม่ได้บันทึกบน Cloud — กดบันทึกข้อมูลสมาชิกเมื่อออนไลน์",
        );
        noticeKind = RescueBannerKind.info;
      }
    });
  });

  Future<void> _save() async {
    if (!form.currentState!.validate()) return;
    await _run(() async {
      final value = await repository.updateName(name.text);
      if (widget.repository == null) {
        await (await LocalDatabaseService.instance.database).delete(
          'settings',
          where: 'key = ?',
          whereArgs: ['profileNameDraft'],
        );
        await AppPreferences.instance.load();
      }
      if (mounted) {
        setState(() {
          profile = value;
          name.text = value.name;
          notice = t("บันทึกข้อมูลสมาชิกแล้ว");
          noticeKind = RescueBannerKind.success;
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

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(AppPreferences.instance.text(t("ออกจากระบบ?"))),
        content: Text(
          AppPreferences.instance.text(
            t("ข้อมูลออฟไลน์ของบัญชีนี้ยังอยู่ในเครื่อง"),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(AppPreferences.instance.text(t("ยกเลิก"))),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE04C4C),
            ),
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(AppPreferences.instance.text(t("ออกจากระบบ"))),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() async {
      await widget.beforeExit?.call();
      await AuthService.instance.signOut();
      _login();
    });
  }

  Future<void> _delete() async {
    final password = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(t("ลบบัญชีถาวร")),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t(
                  "บัญชี โปรไฟล์ ข้อมูลบน Cloud และฐานข้อมูลของบัญชีนี้ในเครื่องจะถูกลบ ไม่สามารถย้อนกลับได้\nกรอกรหัสผ่านปัจจุบันเพื่อยืนยัน",
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: password,
                obscureText: true,
                enableSuggestions: false,
                decoration: InputDecoration(labelText: t("รหัสผ่านปัจจุบัน")),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t("ยกเลิก")),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE04C4C),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(t("ยืนยันลบบัญชี")),
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
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? RescueTheme.darkBackground : RescueTheme.cream;
    final surface = dark ? RescueTheme.darkSurface : Colors.white;
    final ink = dark ? RescueTheme.darkText : RescueTheme.navy;
    final muted = dark ? RescueTheme.darkTextMuted : RescueTheme.muted;
    final line = dark ? RescueTheme.darkBorder : RescueTheme.border;

    final displayName = name.text.trim().isNotEmpty
        ? name.text.trim()
        : (profile != null && profile!.name.trim().isNotEmpty
            ? profile!.name.trim()
            : t("สมาชิก RescueLink"));

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          t("ข้อมูลสมาชิก"),
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: ink,
          ),
        ),
        actions: [
          IconButton(
            tooltip: t("ประวัติข้อความ / Cloud"),
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute(builder: (_) => const ChatHistoryScreen()),
            ),
            icon: const Icon(Icons.cloud_outlined),
          ),
          IconButton(
            tooltip: t("รีเฟรชข้อมูล"),
            onPressed: busy ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              // 1.2 LinearProgressIndicator โค้งมนถ้า busy
              if (busy) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    color: RescueTheme.orange,
                    backgroundColor: dark
                        ? const Color(0xFF382314)
                        : RescueTheme.peach,
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // error / notice แสดงด้วย RescueBanner
              if (error != null) ...[
                RescueBanner(error!, kind: RescueBannerKind.error),
                const SizedBox(height: 12),
              ],
              if (notice != null) ...[
                RescueBanner(notice!, kind: noticeKind),
                const SizedBox(height: 12),
              ],

              // 1.3 การ์ดโปรไฟล์ด้านบน (เมื่อ profile != null)
              if (profile != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: dark
                          ? [const Color(0xFF1E293B), RescueTheme.darkSurface]
                          : [RescueTheme.navy, const Color(0xFF24365C)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      // อวาตาร์วงกลม 72 มีวงแหวนไล่สีส้ม
                      Container(
                        width: 72,
                        height: 72,
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFFFFB17B), RescueTheme.orange],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: CircleAvatar(
                          backgroundColor: RescueTheme.peach,
                          child: const Icon(
                            Icons.person_rounded,
                            size: 38,
                            color: RescueTheme.navy,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // ข้อมูลชื่อ อีเมล และ UID
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              profile!.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.75),
                              ),
                            ),
                            if (kDebugMode) ...[
                              const SizedBox(height: 4),
                              SelectableText(
                                'User UID: ${profile!.id}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontFamily: 'monospace',
                                  color: Colors.white.withValues(alpha: 0.45),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // 1.4 หัวข้อ "ข้อมูลสมาชิก" แล้วการ์ดฟอร์ม
              if (profile != null) ...[
                RescueSectionLabel(t("ข้อมูลสมาชิก")),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: line),
                  ),
                  child: Form(
                    key: form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: name,
                          enabled: !busy,
                          maxLength: 80,
                          decoration: InputDecoration(
                            labelText: t("ชื่อสมาชิก"),
                            prefixIcon: Icon(
                              Icons.person_outline_rounded,
                              color: muted,
                              size: 20,
                            ),
                            filled: true,
                            fillColor: dark
                                ? const Color(0xFF13171F)
                                : const Color(0xFFF9F6F0),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: RescueTheme.orange,
                                width: 1.5,
                              ),
                            ),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? t("กรุณาระบุชื่อสมาชิก")
                                  : null,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 48,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: RescueTheme.orange,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: busy ? null : _save,
                            icon: const Icon(Icons.save_rounded, size: 20),
                            label: Text(
                              t("บันทึกข้อมูลสมาชิก"),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14.5,
                              ),
                            ),
                          ),
                        ),
                        if (widget.repository == null) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 48,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: ink,
                                side: BorderSide(color: line),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: busy
                                  ? null
                                  : () async {
                                      if (!form.currentState!.validate()) return;
                                      await _run(() async {
                                        await AppPreferences.instance
                                            .saveLocalName(name.text);
                                        if (mounted) {
                                          setState(
                                            () => notice = t(
                                              "บันทึกชื่อในเครื่องแล้ว — ยังไม่ได้บันทึกบน Cloud",
                                            ),
                                          );
                                        }
                                      });
                                    },
                              icon: const Icon(Icons.save_outlined, size: 20),
                              label: Text(
                                t("บันทึกชื่อในเครื่อง (ใช้ออฟไลน์)"),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],

              // 1.5 หัวข้อ "ข้อมูลและความปลอดภัย" แล้ว RescueGroup
              RescueSectionLabel(t("ข้อมูลและความปลอดภัย")),
              _buildSecurityGroup(),

              // 1.7 หัวข้อ "จัดการบัญชี"
              RescueSectionLabel(t("จัดการบัญชี")),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFE04C4C),
                    side: const BorderSide(color: Color(0xFFE04C4C)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: busy ? null : _signOut,
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  label: Text(
                    t("ออกจากระบบ"),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              if (profile != null) ...[
                const SizedBox(height: 6),
                Center(
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFE04C4C),
                    ),
                    onPressed: busy ? null : _delete,
                    icon: const Icon(Icons.delete_forever, size: 18),
                    label: Text(
                      t("ลบบัญชีถาวร"),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildSecurityGroup() {
    final sync = SosSyncCoordinator.instance.current;
    return RescueGroup(
      children: [
        if (sync != null) _syncTile(sync),
        RescueTile(
          icon: Icons.medical_information_outlined,
          accent: const Color(0xFFE04C4C),
          label: t("ข้อมูลส่วนตัวและสุขภาพฉุกเฉิน"),
          subtitle: t("ใช้ในเหตุฉุกเฉิน"),
          onTap: busy
              ? null
              : () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const EmergencyProfileScreen(),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _syncTile(SosSyncService sync) {
    return ListenableBuilder(
      listenable: sync,
      builder: (context, _) {
        final hasError = sync.error != null;
        final icon = hasError
            ? Icons.sync_problem
            : Icons.cloud_sync_outlined;
        final accent = hasError
            ? const Color(0xFFE04C4C)
            : RescueTheme.orange;
        final label = t("การซิงก์ข้อมูล");
        final subtitle = sync.busy
            ? t("กำลังซิงก์...")
            : (hasError
                ? t("ซิงก์ไม่สำเร็จ แตะเพื่อดูรายละเอียด")
                : syncAgo(sync.lastSuccess));

        return RescueTile(
          icon: icon,
          accent: accent,
          label: label,
          subtitle: subtitle,
          onTap: () => Navigator.push<void>(
            context,
            MaterialPageRoute(builder: (_) => SyncScreen(service: sync)),
          ),
        );
      },
    );
  }
}
