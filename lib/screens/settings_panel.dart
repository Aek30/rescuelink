import 'package:flutter/material.dart';
import '../services/app_preferences.dart';
import '../services/auth_service.dart';
import '../services/sos_sync_service.dart';
import 'sync_screen.dart';
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
  });
  final int pending;
  final bool rescue, ready;
  final ValueChanged<bool> onRescue;
  final VoidCallback onQueue, onDevice, onConnection, onExit;

  @override
  Widget build(BuildContext context) {
    final prefs = AppPreferences.instance;
    return ListenableBuilder(
      listenable: prefs,
      builder: (context, _) {
        final t = prefs.t;
        final dark = prefs.dark;
        final bg = dark ? RescueTheme.darkBackground : RescueTheme.cream;
        final surface = dark ? RescueTheme.darkSurface : Colors.white;
        final ink = dark ? RescueTheme.darkText : RescueTheme.navy;
        final muted = dark ? RescueTheme.darkTextMuted : RescueTheme.muted;
        final line = dark ? RescueTheme.darkBorder : RescueTheme.border;
        const accent = RescueTheme.orange;
        Future<void> save(String key, bool value) async {
          try {
            await prefs.set(key, value);
          } catch (_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    t(
                      'บันทึกไม่สำเร็จ กรุณาลองใหม่',
                      'Could not save. Please try again.',
                    ),
                  ),
                ),
              );
            }
          }
        }

        Widget row(
          IconData icon,
          String label, {
          Widget? trailing,
          VoidCallback? tap,
        }) => Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              minLeadingWidth: 20,
              horizontalTitleGap: 12,
              leading: Icon(icon, color: ink, size: 23),
              title: Text(
                label,
                style: TextStyle(
                  color: ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing:
                  trailing ?? Icon(Icons.chevron_right, color: muted, size: 22),
              onTap: tap,
            ),
            Divider(height: 1, color: line),
          ],
        );
        Widget toggle(bool value, ValueChanged<bool>? change) =>
            Switch.adaptive(
              value: value,
              onChanged: change,
              activeTrackColor: accent,
              inactiveTrackColor: dark
                  ? RescueTheme.darkBorder
                  : const Color(0xFFE2E8F0),
              inactiveThumbColor: Colors.white,
              activeThumbColor: Colors.white,
              trackOutlineColor: const WidgetStatePropertyAll(
                Colors.transparent,
              ),
            );
        return Material(
          color: bg,
          child: ListView(
            children: [
              Container(
                color: surface,
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
                child: Column(
                  children: [
                    IconButton(
                      onPressed: onDevice,
                      tooltip: t('แก้ไขชื่ออุปกรณ์', 'Edit device name'),
                      padding: EdgeInsets.zero,
                      icon: SizedBox(
                        width: 78,
                        height: 78,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 36,
                              backgroundColor: dark
                                  ? const Color(0xFF1E293B)
                                  : RescueTheme.peach,
                              child: Icon(
                                Icons.person_outline,
                                size: 45,
                                color: dark
                                    ? RescueTheme.orange
                                    : RescueTheme.navy,
                              ),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 2,
                              child: CircleAvatar(
                                radius: 12,
                                backgroundColor: surface,
                                child: CircleAvatar(
                                  radius: 10,
                                  backgroundColor: dark
                                      ? RescueTheme.darkBorder
                                      : RescueTheme.navy,
                                  child: const Icon(
                                    Icons.settings_outlined,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AuthService.instance.session?.email ??
                          t('ผู้ใช้ Guest', 'Guest user'),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: line,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        rescue
                            ? t('หน่วยกู้ภัย', 'Rescue unit')
                            : t('ผู้ใช้ทั่วไป', 'General user'),
                        style: TextStyle(fontSize: 11, color: muted),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: line),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                child: Column(
                  children: [
                    Material(
                      color: dark
                          ? RescueTheme.darkSurfaceElevated
                          : const Color(0xFFFFF4EA),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: dark
                              ? RescueTheme.orange.withValues(alpha: 0.45)
                              : const Color(0xFFFFB17B),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: onQueue,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.wifi_off_rounded,
                                    size: 19,
                                    color: ink,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      t(
                                        'คิวข้อความออฟไลน์',
                                        'Offline message queue',
                                      ),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: ink,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    t('$pending รายการ', '$pending queued'),
                                    style: TextStyle(fontSize: 12, color: ink),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                t(
                                  'ส่งต่อเมื่อเชื่อมต่อกับอุปกรณ์ปลายทางได้',
                                  'Sent when the recipient device reconnects',
                                ),
                                style: TextStyle(fontSize: 11, color: muted),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    row(
                      Icons.cloud_sync_outlined,
                      t('บัญชี / Sync', 'Account / Sync'),
                      tap: () {
                        final sync = SosSyncCoordinator.instance.current;
                        if (sync != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => SyncScreen(service: sync),
                            ),
                          );
                        }
                      },
                    ),
                    row(
                      Icons.health_and_safety_outlined,
                      t('สถานะหน่วยกู้ภัย', 'Rescue unit mode'),
                      trailing: toggle(rescue, ready ? onRescue : null),
                    ),
                    row(
                      Icons.notifications_active_outlined,
                      t('แจ้งเตือน SOS ขณะใช้แอป', 'In-app SOS alerts'),
                      trailing: toggle(
                        prefs.alerts,
                        (v) => save('sosAlerts', v),
                      ),
                    ),
                    row(
                      Icons.dark_mode_outlined,
                      t('โหมดมืด', 'Dark mode'),
                      trailing: toggle(prefs.dark, (v) => save('darkMode', v)),
                    ),
                    row(
                      Icons.translate,
                      t('ภาษา', 'Language'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            prefs.english ? 'English' : 'ไทย',
                            style: TextStyle(color: muted, fontSize: 13),
                          ),
                          Icon(Icons.chevron_right, color: muted),
                        ],
                      ),
                      tap: () => showModalBottomSheet<void>(
                        context: context,
                        builder: (sheet) => SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                title: const Text('ไทย'),
                                trailing: !prefs.english
                                    ? const Icon(Icons.check)
                                    : null,
                                onTap: () {
                                  Navigator.pop(sheet);
                                  save('language', false);
                                },
                              ),
                              ListTile(
                                title: const Text('English'),
                                trailing: prefs.english
                                    ? const Icon(Icons.check)
                                    : null,
                                onTap: () {
                                  Navigator.pop(sheet);
                                  save('language', true);
                                },
                              ),
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  t('ใช้กับหน้าตั้งค่า', 'Applies to settings'),
                                  style: TextStyle(color: muted, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    row(
                      Icons.bluetooth_outlined,
                      t('การเชื่อมต่อและสิทธิ์', 'Connection & permissions'),
                      tap: onConnection,
                    ),
                    row(
                      Icons.info_outline,
                      t('เกี่ยวกับ RescueLink', 'About RescueLink'),
                      tap: () => showAboutDialog(
                        context: context,
                        applicationName: 'RescueLink',
                        applicationVersion: '1.0.0',
                        children: [
                          Text(
                            t(
                              'รับส่งข้อความและ SOS กับอุปกรณ์ใกล้เคียงโดยไม่ใช้อินเทอร์เน็ต',
                              'Exchange messages and SOS with nearby devices without internet.',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: onExit,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: const Color(0xFFE04C4C),
                          side: const BorderSide(color: Color(0xFFE04C4C)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          AuthService.instance.signedIn
                              ? t('ออกจากระบบ', 'Sign out')
                              : t('กลับหน้าเข้าสู่ระบบ', 'Back to sign in'),
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
