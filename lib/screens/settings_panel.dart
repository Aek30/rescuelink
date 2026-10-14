import 'package:flutter/material.dart';
import '../services/app_preferences.dart';
import '../services/auth_service.dart';
import 'member_screen.dart';
import '../theme/rescue_theme.dart';

class SettingsPanel extends StatelessWidget {
  const SettingsPanel({
    super.key,
    required this.pending,
    required this.rescue,
    required this.ready,
    required this.onRescue,
    required this.onQueue,
    required this.onDevice,
    required this.onConnection,
    required this.onExit,
    this.beforeAccountExit,
    this.onResponder,
  });
  final int pending;
  final bool rescue, ready;
  final ValueChanged<bool> onRescue;
  final VoidCallback onQueue, onDevice, onConnection, onExit;
  final Future<void> Function()? beforeAccountExit;
  final VoidCallback? onResponder;

  @override
  Widget build(BuildContext context) {
    final prefs = AppPreferences.instance;
    return ListenableBuilder(
      listenable: prefs,
      builder: (context, _) {
        final t = prefs.text;
        final dark = Theme.of(context).brightness == Brightness.dark;
        final bg = dark ? RescueTheme.darkBackground : RescueTheme.cream;
        final surface = dark ? RescueTheme.darkSurface : Colors.white;
        final ink = dark ? RescueTheme.darkText : RescueTheme.navy;
        final muted = dark ? RescueTheme.darkTextMuted : RescueTheme.muted;
        final line = dark ? RescueTheme.darkBorder : RescueTheme.border;
        final signedIn = AuthService.instance.signedIn;

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
       final header = Container(
  width: double.infinity,
  padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
  decoration: BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: dark
          ? [const Color(0xFF1E293B), RescueTheme.darkSurface]
          : [RescueTheme.navy, const Color(0xFF24365C)],
    ),
    borderRadius: const BorderRadius.vertical(
      bottom: Radius.circular(30),
    ),
  ),
  child: Row(
    children: [
      // ไอคอนอยู่ซ้าย
      GestureDetector(
        onTap: signedIn ? openMember : onDevice,
        child: Semantics(
          button: true,
          label: t("แก้ไขโปรไฟล์"),
          child: SizedBox(
            width: 84,
            height: 84,
            child: Stack(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  padding: const EdgeInsets.all(3.5),
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
                      size: 46,
                      color: RescueTheme.navy,
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: RescueTheme.orange,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: dark
                            ? const Color(0xFF1E293B)
                            : RescueTheme.navy,
                        width: 2.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      size: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(width: 16),
      // ชื่ออยู่ขวา
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              prefs.displayName ?? t("โปรไฟล์ของฉัน"),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.18),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    rescue
                        ? Icons.volunteer_activism_rounded
                        : Icons.person_outline_rounded,
                    size: 13,
                    color: RescueTheme.orange,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      rescue
                          ? t("ผู้ช่วยเหลือทั่วไป • ไม่ยืนยันหน่วยงาน")
                          : t("ผู้ใช้ทั่วไป"),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (signedIn) ...[
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: openMember,
                style: FilledButton.styleFrom(
                  backgroundColor: RescueTheme.orange,
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.manage_accounts_rounded, size: 17),
                label: Text(
                  t("ดู / แก้ไขข้อมูลสมาชิก"),
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ],
  ),
);

        // ---------- offline queue hero ----------
        final queueCard = Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: dark
                    ? [const Color(0xFF3A2416), const Color(0xFF2A1B12)]
                    : [const Color(0xFFFFE6D1), const Color(0xFFFFF4EA)],
              ),
              border: Border.all(
                color: dark
                    ? RescueTheme.orange.withValues(alpha: 0.45)
                    : const Color(0xFFFFB17B),
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: onQueue,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: RescueTheme.orange,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.wifi_off_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t("คิวข้อความออฟไลน์"),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: ink,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            t("ส่งต่อเมื่อเชื่อมต่อกับอุปกรณ์ปลายทางได้"),
                            style: TextStyle(fontSize: 11.5, color: muted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      children: [
                        Text(
                          '$pending',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: RescueTheme.orange,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          t('รายการ'),
                          style: TextStyle(fontSize: 11, color: muted),
                        ),
                      ],
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
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    queueCard,

                    sectionLabel(t("การช่วยเหลือ")),
                    group([
                      tile(
                        Icons.health_and_safety_outlined,
                        t("หน่วยกู้ภัย"),
                        tap: onResponder,
                        accent: const Color(0xFFE04C4C),
                      ),
                    ]),

                    sectionLabel(t("การใช้งานแอป")),
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
                          signedIn
                              ? t("ออกจากระบบ")
                              : t("กลับหน้าเข้าสู่ระบบ"),
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