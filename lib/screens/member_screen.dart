import 'package:flutter/material.dart';
import '../services/member_profile_sync.dart';
import '../services/auth_service.dart';
import '../services/member_service.dart';
import '../services/app_preferences.dart';
import '../services/sos_sync_service.dart';
import '../theme/rescue_theme.dart';
import '../widgets/rescue_ui.dart';
import 'login_screen.dart';
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

  MemberProfile? profile;
  bool busy = false;
  String? error, notice;

  @override
  void initState() {
    super.initState();
    repository =
        widget.repository ?? SupabaseMemberRepository(AuthService.instance);
    if (widget.repository == null) {
      MemberProfileSync.instance.addListener(_onProfileSync);
    }
    _load();
  }

  @override
  void dispose() {
    MemberProfileSync.instance.removeListener(_onProfileSync);
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

  void _apply(MemberProfile value) {
    if (!mounted) return;
    setState(() {
      profile = value;
      notice = value.pending
          ? t('บันทึกในเครื่องแล้ว · รอซิงก์')
          : value.offline
          ? t('กำลังใช้ข้อมูลในเครื่อง')
          : t('ซิงก์ข้อมูลสมาชิกแล้ว');
      error = value.syncError;
    });
  }

  void _onProfileSync() {
    final value = MemberProfileSync.instance.profile;
    if (busy ||
        value == null ||
        value.id != AuthService.instance.session?.userId) {
      return;
    }
    _apply(value);
  }

  Future<void> _load() => _run(() async {
    if (repository is SupabaseMemberRepository) {
      _apply(await (repository as SupabaseMemberRepository).readLocal());
    }
    _apply(await repository.read());
  });

  Future<void> _editName() async {
    final controller = TextEditingController(text: profile?.name ?? '');
    final sheetForm = GlobalKey<FormState>();
    final value = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: sheetForm,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  t('แก้ไขชื่อสมาชิก'),
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  key: const ValueKey('member-name'),
                  controller: controller,
                  autofocus: true,
                  maxLength: 80,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: t('ชื่อสมาชิก'),
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                    counterText: '',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? t('กรุณาระบุชื่อสมาชิก')
                      : value.trim().length > 80
                      ? t('กรุณาระบุชื่อ 1–80 ตัวอักษร')
                      : null,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: () {
                    if (sheetForm.currentState!.validate()) {
                      Navigator.pop(sheetContext, controller.text.trim());
                    }
                  },
                  icon: const Icon(Icons.check_rounded),
                  label: Text(t('บันทึกการเปลี่ยนแปลง')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    // The closing sheet still uses its controller during the route animation.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
    if (value == null || !mounted) return;
    await _run(() async => _apply(await repository.updateName(value)));
  }

  void _showStatusDetails() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('สถานะข้อมูลสมาชิก')),
        content: Text(
          error ?? notice ?? t('ยังไม่ได้ตรวจสอบการซิงก์ข้อมูลสมาชิก'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t('ปิด')),
          ),
        ],
      ),
    );
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
    final ink = dark ? RescueTheme.darkText : RescueTheme.navy;
    return Scaffold(
      appBar: AppBar(
        title: Text(t('ข้อมูลสมาชิก')),
        actions: [
          IconButton(
            tooltip: t('รีเฟรชข้อมูล'),
            onPressed: busy ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (profile != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: dark
                            ? [const Color(0xFF1E293B), RescueTheme.darkSurface]
                            : [RescueTheme.navy, const Color(0xFF24365C)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const CircleAvatar(
                          radius: 28,
                          backgroundColor: RescueTheme.peach,
                          child: Icon(
                            Icons.person_rounded,
                            color: RescueTheme.navy,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  profile!.name.trim().isEmpty
                                      ? t('สมาชิก RescueLink')
                                      : profile!.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
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
                                    color: Colors.white.withValues(alpha: .8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: t('แก้ไขชื่อสมาชิก'),
                          onPressed: busy ? null : _editName,
                          icon: const Icon(Icons.edit_outlined),
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                _inlineStatus(ink),
                RescueSectionLabel(t('ข้อมูลและความปลอดภัย')),
                _buildSecurityGroup(),
                RescueSectionLabel(t('จัดการบัญชี')),
                RescueGroup(
                  children: [
                    RescueTile(
                      icon: Icons.logout_rounded,
                      label: t('ออกจากระบบ'),
                      accent: RescueTheme.danger,
                      onTap: busy ? null : _signOut,
                    ),
                    if (profile != null)
                      RescueTile(
                        icon: Icons.delete_forever,
                        label: t('ลบบัญชีถาวร'),
                        accent: RescueTheme.danger,
                        onTap: busy ? null : _delete,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _inlineStatus(Color ink) {
    final pending = profile?.pending == true;
    final offline = profile?.offline == true;
    final text = busy
        ? t('กำลังตรวจสอบข้อมูลสมาชิก…')
        : pending
        ? t('บันทึกในเครื่องแล้ว · รอซิงก์')
        : error != null
        ? t(
            error == profile?.syncError
                ? 'ตรวจสอบ Cloud ไม่สำเร็จ'
                : 'ดำเนินการไม่สำเร็จ',
          )
        : notice ?? t('ยังไม่ได้ตรวจสอบการซิงก์');
    return Semantics(
      liveRegion: true,
      child: Row(
        children: [
          if (busy)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(
              pending
                  ? Icons.schedule_rounded
                  : error != null || offline
                  ? Icons.cloud_off_outlined
                  : Icons.cloud_done_outlined,
              size: 18,
              color: error != null ? RescueTheme.danger : ink,
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 12, color: ink)),
          ),
          if (!busy && (error != null || pending || offline))
            TextButton(
              onPressed: _showStatusDetails,
              child: Text(t('รายละเอียด')),
            ),
        ],
      ),
    );
  }

  Widget _buildSecurityGroup() {
    final sos = SosSyncCoordinator.instance.current;
    return RescueGroup(
      children: [
        RescueTile(
          icon: Icons.person_outline_rounded,
          label: t('ซิงก์ข้อมูลสมาชิก'),
          subtitle: profile == null
              ? t('ยังไม่มีข้อมูล')
              : profile!.pending
              ? t('รอซิงก์ชื่อสมาชิก')
              : profile!.offline
              ? t('กำลังใช้ข้อมูลในเครื่อง')
              : t('ชื่อและข้อมูลบัญชี'),
          onTap: busy ? null : _load,
        ),
        if (sos != null)
          ListenableBuilder(
            listenable: sos,
            builder: (context, _) => RescueTile(
              icon: sos.error != null
                  ? Icons.sync_problem
                  : Icons.cloud_sync_outlined,
              label: t('การซิงก์ SOS'),
              subtitle: sos.busy
                  ? t('กำลังซิงก์ SOS…')
                  : sos.error != null
                  ? t('ซิงก์ SOS ไม่สำเร็จ')
                  : syncAgo(sos.lastSuccess),
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(builder: (_) => SyncScreen(service: sos)),
              ),
            ),
          ),
        RescueTile(
          icon: Icons.medical_information_outlined,
          accent: RescueTheme.danger,
          label: t('ข้อมูลส่วนตัวและสุขภาพฉุกเฉิน'),
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
}
