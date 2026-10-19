import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/app_preferences.dart';
import '../services/auth_service.dart';
import '../services/member_profile_sync.dart';
import 'member_screen.dart';
import '../theme/rescue_theme.dart';

class SettingsPanel extends StatelessWidget {
  const SettingsPanel({
    super.key,
    required this.rescue,
    required this.ready,
    required this.onRescue,
    required this.onDevice,
    required this.onConnection,
    required this.onExit,
    this.beforeAccountExit,
    this.onResponder,
  });
  final bool rescue, ready;
  final ValueChanged<bool> onRescue;
  final VoidCallback onDevice, onConnection, onExit;
  final Future<void> Function()? beforeAccountExit;
  final VoidCallback? onResponder;

  static String? _sessionMetadataName(AccountSession? session) {
    final raw = session?.serialized;
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final user = decoded['user'];
        if (user is Map<String, dynamic>) {
          final meta = user['user_metadata'];
          if (meta is Map<String, dynamic>) {
            final name = (meta['display_name'] ?? meta['full_name'])
                ?.toString()
                .trim();
            if (name != null && name.isNotEmpty) return name;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final prefs = AppPreferences.instance;
    final auth = AuthService.instance;
    final profileSync = MemberProfileSync.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([prefs, auth, profileSync]),
      builder: (context, _) {
        final t = prefs.text;
        final dark = Theme.of(context).brightness == Brightness.dark;
        final bg = Theme.of(context).scaffoldBackgroundColor;
        final surface = dark ? RescueTheme.darkSurface : Colors.white;
        final ink = dark ? RescueTheme.darkText : RescueTheme.navy;
        final muted = dark ? RescueTheme.darkTextMuted : RescueTheme.muted;
        final line = dark ? RescueTheme.darkBorder : RescueTheme.border;
        final session = auth.session;
        final signedIn = auth.signedIn;
        final syncedProfile =
            session != null && profileSync.profile?.id == session.userId
            ? profileSync.profile
            : null;
        final memberName =
            [
                  prefs.displayName,
                  syncedProfile?.name,
                  _sessionMetadataName(session),
                ]
                .map((s) => s?.trim())
                .firstWhere(
                  (s) => s != null && s.isNotEmpty,
                  orElse: () => null,
                ) ??
            t("โปรไฟล์ของฉัน");
        final memberEmail =
            (session?.email.trim().isNotEmpty == true
                ? session!.email.trim()
                : syncedProfile?.email.trim()) ??
            '';

        Future<void> save(String key, bool value) async {
          try {
            await prefs.set(key, value);
          } catch (_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(t("บันทึกไม่สำเร็จ กรุณาลองใหม่"))),
              );
            }
          }
        }

        void openMember() => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => MemberScreen(beforeExit: beforeAccountExit),
          ),
        );

        Future<void> openSheet(WidgetBuilder builder) =>
            showModalBottomSheet<void>(
              context: context,
              backgroundColor: surface,
              showDragHandle: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              ),
              builder: builder,
            );

        String themeLabel(ThemeMode m) => switch (m) {
          ThemeMode.system => t("ตามระบบ"),
          ThemeMode.light => t("โหมดสว่าง"),
          ThemeMode.dark => t("โหมดมืด"),
        };

        // ---------- building blocks ----------
        Widget sectionLabel(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(6, 22, 6, 8),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: muted,
            ),
          ),
        );

        Widget group(List<Widget> children) => Material(
          color: surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: line),
          ),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) Divider(height: 1, indent: 66, color: line),
                children[i],
              ],
            ],
          ),
        );

        Widget tile(
          IconData icon,
          String label, {
          String? subtitle,
          Widget? trailing,
          VoidCallback? tap,
          Color? accent,
        }) {
          final c = accent ?? RescueTheme.orange;
          return InkWell(
            onTap: tap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: c.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: c, size: 21),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            color: ink,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (subtitle != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              subtitle,
                              style: TextStyle(color: muted, fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  ),
                  trailing ??
                      Icon(Icons.chevron_right_rounded, color: muted, size: 24),
                ],
              ),
            ),
          );
        }

        Widget option(String label, bool selected, VoidCallback onTap) =>
            ListTile(
              onTap: onTap,
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              title: Text(
                label,
                style: TextStyle(
                  color: ink,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
              trailing: selected
                  ? const Icon(
                      Icons.check_circle_rounded,
                      color: RescueTheme.orange,
                    )
                  : Icon(Icons.circle_outlined, color: line),
            );

        Widget sheetNote(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
          child: Text(text, style: TextStyle(color: muted, fontSize: 12)),
        );

        // ---------- header ----------
        final header = Material(
          color: Colors.transparent,
          child: InkWell(
            key: const ValueKey('profile-header'),
            onTap: openMember,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(28),
            ),
            child: Ink(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: dark
                      ? [const Color(0xFF1E293B), RescueTheme.darkSurface]
                      : [RescueTheme.navy, const Color(0xFF24365C)],
                ),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(28),
                ),
              ),
              child: Semantics(
                button: true,
                label: t("ข้อมูลสมาชิก"),
                child: Row(
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      padding: const EdgeInsets.all(2.5),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFFFFB17B), RescueTheme.orange],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const CircleAvatar(
                        backgroundColor: RescueTheme.peach,
                        child: Icon(
                          Icons.person_rounded,
                          size: 34,
                          color: RescueTheme.navy,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            memberName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          if (memberEmail.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              memberEmail,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.78),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white.withValues(alpha: 0.75),
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        // ---------- page ----------
        return Material(
          color: bg,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              header,
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    sectionLabel(t("การช่วยเหลือ")),
                    group([
                      tile(
                        Icons.health_and_safety_outlined,
                        t("หน่วยกู้ภัย"),
                        tap: onResponder,
                        accent: RescueTheme.rescue,
                        trailing: Semantics(
                          label: t("หน่วยกู้ภัย"),
                          child: Switch.adaptive(
                            key: const ValueKey('rescue-mode-switch'),
                            value: rescue,
                            onChanged: ready ? onRescue : null,
                            activeTrackColor: RescueTheme.rescue,
                          ),
                        ),
                      ),
                    ]),

                    sectionLabel(t("การตั้งค่าแอป")),
                    group([
                      tile(
                        Icons.translate_rounded,
                        t("ภาษา"),
                        subtitle: prefs.english ? 'English' : 'ไทย',
                        tap: () => openSheet(
                          (sheet) => SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                option('ไทย', !prefs.english, () {
                                  Navigator.pop(sheet);
                                  save('language', false);
                                }),
                                option('English', prefs.english, () {
                                  Navigator.pop(sheet);
                                  save('language', true);
                                }),
                                sheetNote(
                                  t(
                                    "ภาษาเปลี่ยนกับหน้าข้อความ SOS ฉัน และหน่วยกู้ภัย",
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      tile(
                        Icons.dark_mode_outlined,
                        t("ธีมการแสดงผล"),
                        subtitle: themeLabel(prefs.themeMode),
                        tap: () => openSheet(
                          (sheet) => SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (final mode in ThemeMode.values)
                                  option(
                                    themeLabel(mode),
                                    prefs.themeMode == mode,
                                    () async {
                                      Navigator.pop(sheet);
                                      try {
                                        await prefs.setTheme(mode);
                                      } catch (_) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                t("บันทึกไม่สำเร็จ"),
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                const SizedBox(height: 12),
                              ],
                            ),
                          ),
                        ),
                      ),
                      tile(
                        Icons.notifications_active_outlined,
                        t("การแจ้งเตือน"),
                        subtitle: prefs.alerts ? t("เปิดอยู่") : t("ปิดอยู่"),
                        tap: () => openSheet(
                          (_) => ListenableBuilder(
                            listenable: prefs,
                            builder: (context, _) => SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SwitchListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                    ),
                                    activeThumbColor: RescueTheme.orange,
                                    title: Text(
                                      t("ข้อความและ SOS ขณะใช้แอป"),
                                      style: TextStyle(
                                        color: ink,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    value: prefs.alerts,
                                    onChanged: (v) => save('sosAlerts', v),
                                  ),
                                  sheetNote(
                                    t(
                                      "ระบบเดิมใช้การแจ้งเตือนร่วมกัน ยังไม่รองรับแยกประเภท, Push Notification หรือแจ้งเตือนยืนยันเคส",
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ]),

                    sectionLabel(t("ระบบ")),
                    group([
                      tile(
                        Icons.bluetooth_outlined,
                        t("การเชื่อมต่อและสิทธิ์"),
                        tap: onConnection,
                      ),
                      tile(
                        Icons.info_outline_rounded,
                        t("เกี่ยวกับ RescueLink"),
                        tap: () => showAboutDialog(
                          context: context,
                          applicationName: 'RescueLink',
                          applicationVersion: '1.0.0',
                          children: [
                            Text(
                              t(
                                "รับส่งข้อความและ SOS กับอุปกรณ์ใกล้เคียงโดยไม่ใช้อินเทอร์เน็ต",
                              ),
                            ),
                          ],
                        ),
                      ),
                    ]),

                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (dialog) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(22),
                              ),
                              title: Text(t("ออกจากระบบ?")),
                              content: Text(
                                t("ประวัติและคิวของบัญชีนี้จะเก็บไว้ในเครื่อง"),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialog, false),
                                  child: Text(t("ยกเลิก")),
                                ),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFFE04C4C),
                                  ),
                                  onPressed: () => Navigator.pop(dialog, true),
                                  child: Text(t("ออกจากระบบ")),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true && context.mounted) onExit();
                        },
                        icon: Icon(
                          signedIn
                              ? Icons.logout_rounded
                              : Icons.arrow_back_rounded,
                          size: 19,
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFE04C4C),
                          side: const BorderSide(color: Color(0xFFE04C4C)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        label: Text(
                          signedIn ? t("ออกจากระบบ") : t("กลับหน้าเข้าสู่ระบบ"),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
