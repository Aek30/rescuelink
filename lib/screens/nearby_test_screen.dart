import '../services/app_preferences.dart';
import '../services/auth_service.dart';
import '../models/message_model.dart';
import '../models/incoming_notice.dart';
import '../widgets/location_button.dart';
import 'dart:async';
import 'settings_panel.dart';
import 'login_screen.dart';
import 'package:flutter/material.dart';

import '../services/nearby_service.dart';
import '../services/media_service.dart';
import '../services/message_service.dart';
import '../services/local_database_service.dart';
import '../services/permission_service.dart';
import '../widgets/device_tile.dart';
import '../widgets/presence_list.dart';
import '../widgets/nearby_mini_map.dart';
import 'chat_screen.dart';
import 'sos_screen.dart';
import '../widgets/outbox_queue.dart';
import '../theme/rescue_theme.dart';
import '../widgets/brand_header.dart';

class NearbyTestScreen extends StatefulWidget {
  const NearbyTestScreen({super.key});

  @override
  State<NearbyTestScreen> createState() => _NearbyTestScreenState();
}

class _NearbyTestScreenState extends State<NearbyTestScreen>
    with WidgetsBindingObserver {
  final _service = NearbyService();

  late final TextEditingController _name;
  late final MessageService _messages;
  late final MediaService _media;

  bool _busy = false;
  int _tab = 0;
  bool _foreground = true;
  Timer? _noticeTimer;
  final List<IncomingNotice> _notices = [];
  IncomingNotice? _shownNotice;

  static const Color _primary = RescueTheme.orangeInk;
  static const Color _success = Color(0xFF2E9B6F);
  static const Color _warning = Color(0xFFF0A63A);

  @override
  void initState() {
    super.initState();

    _name = TextEditingController(text: _service.deviceName);

    // Step 1: สร้าง _messages ก่อนเพื่อให้ได้ database instance
    final database = LocalDatabaseService.instance;

    // Step 2: สร้าง _media โดยใช้ database จาก _messages
    _media = MediaService(
      nearby: _service,
      database: database,
      getEndpointForPeer: (peerId) {
        for (final d in _service.connectedDevices) {
          if (_messages.getPeerForEndpoint(d.endpointId) == peerId) {
            return d.endpointId;
          }
        }
        return null;
      },
    );

    // Step 3: สร้าง _messages ใหม่พร้อม mediaService (late binding pattern)
    _messages = MessageService(
      nearbyService: _service,
      database: database,
      mediaService: _media,
    );

    _messages.onNotice = _receiveNotice;
    _messages
        .initialize()
        .then((_) async {
          if (!mounted) return;
          await _service.connectionSession.listenForNotifications(_openNotice);
        })
        .catchError((Object error) {
          debugPrint('Notification setup: $error');
        });
    AppPreferences.instance.load().catchError((Object _) {});

    WidgetsBinding.instance.addObserver(this);
  }

  void _receiveNotice(IncomingNotice notice) {
    if (!mounted) return;
    if (!_foreground) {
      unawaited(
        _service.connectionSession.notify(notice).catchError((Object e) {
          debugPrint('Notification: $e');
        }),
      );
      return;
    }
    _notices.add(notice);
    if (_shownNotice == null) _showNextNotice();
  }

  void _showNextNotice() {
    if (!mounted || _notices.isEmpty) return;
    final notice = _notices.removeAt(0);
    _shownNotice = notice;
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        leading: Icon(
          notice.sos == null ? Icons.chat_bubble_outline : Icons.sos,
        ),
        content: Text(
          '${notice.title}\n${notice.body}',
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          TextButton(
            onPressed: () {
              _dismissNotice();
              _openNotice(notice);
            },
            child: Text(notice.sos == null ? 'เปิดแชต' : 'ดู SOS'),
          ),
          if (notice.sos != null)
            TextButton(
              onPressed: () {
                _dismissNotice();
                _openChat(notice.peerId);
              },
              child: const Text('แชต'),
            ),
          TextButton(onPressed: _dismissNotice, child: const Text('ปิด')),
        ],
      ),
    );
    _noticeTimer = Timer(const Duration(seconds: 10), _dismissNotice);
  }

  void _dismissNotice() {
    _noticeTimer?.cancel();
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentMaterialBanner();
    _shownNotice = null;
    _showNextNotice();
  }

  void _openChat(String peerId) {
    if (!mounted || !_messages.peers.containsKey(peerId)) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(
          service: _messages,
          peerId: peerId,
          mediaService: _media,
        ),
      ),
    );
  }

  void _openNotice(IncomingNotice notice) {
    if (!mounted || !_messages.peers.containsKey(notice.peerId)) return;
    if (notice.sos == null) {
      _openChat(notice.peerId);
      return;
    }
    // Prefer current incident data over the notification's older snapshot.
    final current = _messages.presence[notice.peerId]?.sos;
    final alert = current?.incidentId == notice.sos!.incidentId
        ? current!
        : notice.sos!;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                alert.summary,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (alert.location != null)
                LocationButton(location: alert.location!),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  _openChat(notice.peerId);
                },
                icon: const Icon(Icons.chat),
                label: const Text('แชตกับผู้ขอความช่วยเหลือ'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _service.setForeground(false);
    } else if (state == AppLifecycleState.resumed) {
      _service.setForeground(true);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;

    setState(() {
      _busy = true;
    });

    try {
      _service.setName(_name.text.trim());

      await action();
    } catch (e) {
      // เก็บรายละเอียดจริงไว้ใน Service
      // แต่ไม่แสดง Error ภาษาอังกฤษยาว ๆ บน UI
      _service.reportError('เกิดข้อผิดพลาดระหว่างการทำงาน: $e');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _openSettings() async {
    await _run(() async {
      final opened = await _service.permissions.openSettings();

      if (!opened) {
        _service.reportError(
          'ไม่สามารถเปิดการตั้งค่าแอปได้ กรุณาเปิดการตั้งค่า Android แล้วเลือก RescueLink',
        );
      }
    });
  }

  // =========================================================
  // ตรวจสอบสถานะ Permission
  // =========================================================

  bool _permissionIsReady(Object? status) {
    return PermissionService.statusIsReady(status.toString());
  }

  bool get _permissionsReady {
    final statuses = _service.permissions.statuses;

    if (statuses.isEmpty) {
      return false;
    }

    return statuses.values.every(_permissionIsReady);
  }

  String _permissionNameThai(String value) {
    final text = value.toLowerCase();

    if (text.contains('bluetooth')) {
      return 'บลูทูธ';
    }

    if (text.contains('nearby')) {
      return 'อุปกรณ์ใกล้เคียง';
    }

    if (text.contains('location service')) {
      return 'บริการตำแหน่ง';
    }

    if (text.contains('location')) {
      return 'ตำแหน่งที่ตั้ง';
    }

    if (text.contains('wifi') || text.contains('wi-fi')) {
      return 'Wi-Fi';
    }

    return value;
  }

  String _permissionStatusThai(Object? status) {
    final value = status.toString().toLowerCase();

    if (value.contains('not required')) {
      return 'ไม่จำเป็นสำหรับ Android รุ่นนี้';
    }
    if (value.contains('uses location')) return 'ใช้สิทธิ์ตำแหน่งแทน';
    if (value.contains('radio off')) return 'อนุญาตแล้ว แต่ยังไม่ได้เปิดบลูทูธ';

    if (value.contains('not checked')) {
      return 'ยังไม่ได้ตรวจสอบ';
    }

    if (value.contains('granted') || value.contains('allowed')) {
      return 'อนุญาตแล้ว';
    }

    if (value.contains('denied')) {
      return 'ไม่อนุญาต';
    }

    if (value.contains('enabled') || value == 'on') {
      return 'เปิดใช้งาน';
    }

    if (value.contains('disabled') || value == 'off') {
      return 'ปิดใช้งาน';
    }

    if (value.contains('available')) {
      return 'พร้อมใช้งาน';
    }

    if (value == 'true') {
      return 'พร้อมใช้งาน';
    }

    if (value == 'false') {
      return 'ยังไม่พร้อม';
    }

    return 'ต้องตรวจสอบ';
  }

  bool get _nearbyActive => _service.isAdvertising || _service.isDiscovering;

  // =========================================================
  // ข้อความสถานะระบบภาษาไทย
  // =========================================================

  String get _connectionStatusThai {
    if (_service.connectedDevices.isNotEmpty) {
      final count = _service.connectedDevices.length;

      if (count == 1) {
        return 'เชื่อมต่อกับอุปกรณ์แล้ว 1 เครื่อง';
      }

      return 'เชื่อมต่อกับอุปกรณ์แล้ว $count เครื่อง';
    }

    if (_service.isAdvertising && _service.isDiscovering) {
      return 'กำลังเปิดให้ค้นพบและค้นหาอุปกรณ์ใกล้เคียง';
    }

    if (_service.isAdvertising) {
      return 'กำลังเปิดให้อุปกรณ์อื่นค้นพบเครื่องนี้';
    }

    if (_service.isDiscovering) {
      return 'กำลังค้นหาอุปกรณ์ RescueLink ที่อยู่ใกล้เคียง';
    }

    return 'ยังไม่ได้เริ่มการเชื่อมต่อ';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _noticeTimer?.cancel();
    _service.connectionSession.detachNotifications();

    _messages.dispose();
    _media.dispose();
    _service.dispose();
    _name.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      appBar: _tab == 4
          ? null
          : AppBar(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              elevation: 0,
              scrolledUnderElevation: 0,
              titleSpacing: 18,

              title: Row(
                children: [
                  const _RescueLogo(),

                  const SizedBox(width: 10),

                  Flexible(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Rescue',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const TextSpan(
                            text: 'Link',
                            style: TextStyle(color: Color(0xFFFF641F)),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                      ),
                    ),
                  ),
                ],
              ),

              actions: [
                IconButton(
                  tooltip: 'ตั้งค่าแอป',
                  onPressed: () => setState(() => _tab = 4),
                  icon: const Icon(Icons.settings_outlined),
                ),

                const SizedBox(width: 8),
              ],
            ),

      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) {
          if (value == 2) {
            if (_messages.ready) {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => SosScreen(service: _messages),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('กำลังเตรียมข้อมูล SOS กรุณารอสักครู่'),
                ),
              );
            }
          } else {
            setState(() => _tab = value);
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.radar), label: 'ใกล้ฉัน'),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'ข้อความ',
          ),
          NavigationDestination(
            icon: CircleAvatar(
              backgroundColor: RescueTheme.danger,
              radius: 20,
              child: Icon(Icons.sos, color: Colors.white, size: 26),
            ),
            label: 'SOS',
          ),
          NavigationDestination(
            icon: Icon(Icons.outbox_outlined),
            label: 'คิวส่ง',
          ),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'ฉัน'),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([_service, _messages]),

          builder: (context, _) {
            if (_tab == 1) {
              return ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  const BrandHeader(
                    title: 'ทุกบทสนทนา เชื่อมถึงกัน',
                    subtitle:
                        'ส่งข้อความถึงผู้คนที่เชื่อมต่อกับคุณ แม้ไม่มีอินเทอร์เน็ต',
                    icon: Icons.forum_outlined,
                    eyebrow: 'ข้อความ • อยู่ใกล้กันเสมอ',
                  ),
                  _buildConversations(),
                ],
              );
            }
            if (_tab == 3) return _buildQueue();
            if (_tab == 4) {
              return SettingsPanel(
                pending: _messages.messages
                    .where(
                      (m) =>
                          m.senderId == _messages.myId &&
                          m.status == MessageStatus.pending &&
                          (m.type == MessageType.message ||
                              m.type == MessageType.sos),
                    )
                    .length,
                rescue: _messages.rescueMode,
                ready: _messages.ready && !_busy,
                onRescue: (value) => _run(() => _messages.setRescueMode(value)),
                onQueue: () => setState(() => _tab = 3),
                onDevice: _openConnectionSettings,
                onConnection: _openConnectionSettings,
                onExit: () => _run(() async {
                  await _service.stopAll();
                  if (AuthService.instance.signedIn) {
                    try {
                      await AuthService.instance.signOut();
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('ออกจากระบบไม่สำเร็จ กรุณาลองใหม่'),
                          ),
                        );
                      }
                      return;
                    }
                  }
                  if (!context.mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute<void>(
                      builder: (_) => const LoginScreen(),
                    ),
                    (_) => false,
                  );
                }),
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 36),

              children: [
                _buildHeroCard(),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy ? null : () => _run(_service.startAutomatic),
                  icon: const Icon(Icons.wifi_tethering),
                  label: Text(
                    _service.autoConnect
                        ? 'โหมดค้นหาและเชื่อมต่ออัตโนมัติเปิดอยู่'
                        : 'เริ่มรับส่ง SOS / เชื่อมต่ออัตโนมัติ',
                  ),
                ),
                const Text(
                  'เปิดโหมดนี้ทั้งสองเครื่อง เพื่อค้นหาและเชื่อมต่อกันก่อนรับสถานะ SOS',
                ),
                if (_service.backgroundActive)
                  const Text(
                    'คงการเชื่อมต่อขณะสลับแอป/ดับหน้าจอ • กดหยุดเมื่อเลิกใช้งาน',
                  ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: !_messages.ready
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => SosScreen(service: _messages),
                          ),
                        ),
                  icon: const Icon(Icons.sos),
                  label: Text(
                    'SOS / หน่วยช่วยเหลือ • ${_messages.activeSosCount} คำขอที่ยังไม่หมดอายุ',
                  ),
                ),

                PresenceList(service: _messages),
                if (_busy) ...[
                  const SizedBox(height: 14),
                  const LinearProgressIndicator(),
                ],

                if (_service.lastError != null) ...[
                  const SizedBox(height: 14),
                  _buildErrorCard(),
                ],

                const SizedBox(height: 24),

                _buildNearbyDevices(),

                const SizedBox(height: 30),

                _buildConnectedDevices(),

                const SizedBox(height: 24),

                _buildOfflineInfo(),

                const SizedBox(height: 18),

                Center(
                  child: Text(
                    'ทำงานได้โดยไม่ต้องใช้อินเทอร์เน็ต',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _openConnectionSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('การเชื่อมต่อและสิทธิ์')),
          body: ListenableBuilder(
            listenable: _service,
            builder: (context, _) => ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildDeviceName(),
                _buildPermissionCard(),
                if (_service.lastError != null) _buildErrorCard(),
                const SizedBox(height: 20),
                _buildConnectionMode(),
                const SizedBox(height: 20),
                _buildOfflineInfo(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQueue() => OutboxQueue(
    messages: _messages.messages
        .where((m) => m.senderId == _messages.myId)
        .toList(),
    peers: _messages.peers,
    ready: _messages.ready,
    busy: _busy,
    hasError: _messages.error != null,
    onRetry: () => _run(_messages.retry),
  );

  // =========================================================
  // กล่องสถานะหลัก
  // =========================================================

  Widget _buildHeroCard() {
    final connectedCount = _service.connectedDevices.length;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String title;
    String description;
    String status;
    IconData icon;
    Color statusColor;

    if (connectedCount > 0) {
      title = 'เชื่อมต่อแล้ว';
      description = connectedCount == 1
          ? 'กำลังเชื่อมต่อกับอุปกรณ์ใกล้เคียง 1 เครื่อง'
          : 'กำลังเชื่อมต่อกับอุปกรณ์ใกล้เคียง $connectedCount เครื่อง';
      status = 'เชื่อมต่อ';
      icon = Icons.link_rounded;
      statusColor = const Color(0xFF34D399);
    } else if (_service.isDiscovering) {
      title = 'กำลังค้นหาอุปกรณ์';
      description = 'กำลังค้นหาอุปกรณ์ RescueLink ที่อยู่ใกล้คุณ';
      status = 'กำลังค้นหา';
      icon = Icons.radar_rounded;
      statusColor = const Color(0xFFFBBF24);
    } else if (_service.isAdvertising) {
      title = 'พร้อมให้อุปกรณ์อื่นค้นพบ';
      description = 'โทรศัพท์ RescueLink เครื่องอื่นสามารถค้นหาเครื่องนี้ได้';
      status = 'พร้อมค้นพบ';
      icon = Icons.cell_tower_rounded;
      statusColor = const Color(0xFF38BDF8);
    } else {
      title = 'พร้อมเชื่อมต่อแบบออฟไลน์';
      description = 'ติดต่อกับอุปกรณ์ใกล้เคียงได้โดยไม่ต้องใช้อินเทอร์เน็ต';
      status = 'ออฟไลน์';
      icon = Icons.shield_outlined;
      statusColor = const Color(0xFF94A3B8);
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0x3394A3B8) : const Color(0x22102130),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.45)
                : RescueTheme.navy.withValues(alpha: 0.16),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22.8),
        child: Stack(
          children: [
            // Background Artwork
            Positioned.fill(
              child: Image.asset(
                'assets/onboarding/nearby.png',
                fit: BoxFit.cover,
                alignment: const Alignment(0, -0.15),
              ),
            ),

            // Smooth multi-stop gradient overlay
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isDark
                        ? [
                            const Color(0x38091624),
                            const Color(0x28091624),
                            const Color(0x8C06101B),
                            const Color(0xEB040B13),
                          ]
                        : [
                            const Color(0x30091624),
                            const Color(0x22091624),
                            const Color(0x82071321),
                            const Color(0xE0050E18),
                          ],
                    stops: const [0.0, 0.32, 0.62, 1.0],
                  ),
                ),
              ),
            ),

            // Foreground Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0x520B1928),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22),
                            width: 1,
                          ),
                        ),
                        child: Icon(icon, color: Colors.white, size: 24),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x520B1928),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: statusColor.withValues(alpha: 0.6),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              status,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 11.5,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      shadows: [
                        Shadow(
                          color: Colors.black87,
                          blurRadius: 8,
                          offset: Offset(0, 1.5),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.90),
                      height: 1.38,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w400,
                      shadows: const [
                        Shadow(
                          color: Colors.black87,
                          blurRadius: 6,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x520B1928),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.smartphone_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            _name.text,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // ชื่ออุปกรณ์
  // =========================================================

  Widget _buildDeviceName() {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          const _SectionTitle(
            icon: Icons.badge_outlined,
            title: 'อุปกรณ์ของฉัน',
            subtitle: 'ชื่อนี้จะแสดงบนโทรศัพท์ RescueLink เครื่องอื่น',
          ),

          const SizedBox(height: 16),

          TextField(
            controller: _name,

            enabled: !_busy && !_service.hasActivity,

            maxLength: 32,

            decoration: InputDecoration(
              hintText: 'ชื่ออุปกรณ์ RescueLink',

              prefixIcon: const Icon(Icons.smartphone_rounded),

              filled: true,

              fillColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF161C24)
                  : const Color(0xFFFCF8F1),

              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),

                borderSide: BorderSide.none,
              ),

              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),

                borderSide: BorderSide(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF283442)
                      : const Color(0xFFEAE2D8),
                ),
              ),

              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),

                borderSide: const BorderSide(color: _primary, width: 1.5),
              ),
            ),

            onChanged: (_) {
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  // =========================================================
  // สิทธิ์การเข้าถึง
  // =========================================================

  Widget _buildPermissionCard() {
    final statuses = _service.permissions.statuses;

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              Expanded(
                child: _SectionTitle(
                  icon: _permissionsReady
                      ? Icons.verified_user_outlined
                      : Icons.admin_panel_settings_outlined,

                  title: 'สิทธิ์การเข้าถึง',

                  subtitle: _permissionsReady
                      ? 'สิทธิ์ที่จำเป็นพร้อมใช้งานแล้ว'
                      : 'อนุญาตสิทธิ์ที่จำเป็นก่อนเริ่มเชื่อมต่อ',
                ),
              ),

              _StatusChip(
                text: _permissionsReady ? 'พร้อมใช้งาน' : 'ต้องตรวจสอบ',

                color: _permissionsReady ? _success : _warning,
              ),
            ],
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,

            child: FilledButton.icon(
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                      await _service.checkPermissions();
                    }),

              icon: const Icon(Icons.security_rounded),

              label: Text(
                _permissionsReady
                    ? 'ตรวจสอบสิทธิ์อีกครั้ง'
                    : 'ตรวจสอบ / อนุญาตสิทธิ์',
              ),

              style: FilledButton.styleFrom(
                backgroundColor: _primary,

                padding: const EdgeInsets.symmetric(vertical: 14),

                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),

          const SizedBox(height: 6),

          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,

            title: const Text(
              'รายละเอียดสิทธิ์',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),

            children: [
              for (final item in statuses.entries)
                _PermissionRow(
                  name: _permissionNameThai(item.key),

                  value: _permissionStatusThai(item.value),

                  ok: _permissionIsReady(item.value),
                ),

              const SizedBox(height: 8),

              Align(
                alignment: Alignment.centerLeft,

                child: TextButton.icon(
                  onPressed: _busy ? null : _openSettings,

                  icon: const Icon(Icons.settings_outlined),

                  label: const Text('เปิดการตั้งค่าแอป'),
                ),
              ),

              Padding(
                padding: const EdgeInsets.only(bottom: 8),

                child: Text(
                  'ควรเปิด Bluetooth, Wi-Fi และบริการตำแหน่งเพื่อให้การค้นหาอุปกรณ์ทำงานได้ตามปกติ',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF666666),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================
  // การเชื่อมต่อ
  // =========================================================

  Widget _buildConnectionMode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        const Text(
          'เชื่อมต่ออุปกรณ์ใกล้เคียง',

          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),

        const SizedBox(height: 5),

        Text(
          'เลือกวิธีที่ต้องการให้โทรศัพท์เครื่องนี้ทำงาน',

          style: TextStyle(color: Colors.grey.shade600),
        ),

        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: _ModeCard(
                icon: Icons.cell_tower_rounded,

                title: 'เปิดให้ค้นพบ',

                subtitle: 'ให้อุปกรณ์อีกเครื่องค้นหาโทรศัพท์นี้',

                active: _service.isAdvertising,

                onTap: _busy || _service.isAdvertising
                    ? null
                    : () => _run(_service.startAdvertising),
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: _ModeCard(
                icon: Icons.radar_rounded,

                title: 'ค้นหาอุปกรณ์',

                subtitle: 'ค้นหาโทรศัพท์ RescueLink ที่อยู่ใกล้เคียง',

                active: _service.isDiscovering,

                onTap: _busy || _service.isDiscovering
                    ? null
                    : () => _run(_service.startDiscovery),
              ),
            ),
          ],
        ),

        if (_nearbyActive) ...[
          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,

            child: OutlinedButton.icon(
              onPressed: _busy ? null : () => _run(_service.stopAll),

              icon: const Icon(Icons.stop_circle_outlined),

              label: const Text('หยุดการทำงานใกล้เคียง'),

              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade700,

                padding: const EdgeInsets.symmetric(vertical: 14),

                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],

        const SizedBox(height: 12),

        Container(
          width: double.infinity,

          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),

          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF161C24)
                : Colors.white,

            borderRadius: BorderRadius.circular(14),

            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF283442)
                  : const Color(0xFFEAE2D8),
            ),
          ),

          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Icon(
                Icons.info_outline,
                size: 19,
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF94A3B8)
                    : Colors.grey.shade600,
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Text(
                  _connectionStatusThai,

                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.85),
                    height: 1.4,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================
  // อุปกรณ์ใกล้เคียง
  // =========================================================

  Widget _buildNearbyDevices() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        _ListHeading(
          title: 'อุปกรณ์ใกล้เคียง',

          count: _service.discoveredDevices.length,
        ),

        const SizedBox(height: 12),

        NearbyMiniMap(service: _messages),
        const SizedBox(height: 12),
        if (_service.discoveredDevices.isEmpty)
          _EmptyState(
            icon: Icons.radar_rounded,

            title: _service.isDiscovering
                ? 'กำลังค้นหาอุปกรณ์...'
                : 'ยังไม่พบอุปกรณ์',

            description: _service.isDiscovering
                ? 'เปิด RescueLink บนโทรศัพท์อีกเครื่องและวางโทรศัพท์ให้อยู่ใกล้กัน'
                : 'ให้อีกเครื่องกด "เปิดให้ค้นพบ" จากนั้นกด "ค้นหาอุปกรณ์" บนเครื่องนี้',
          ),

        for (final device in _service.discoveredDevices)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),

            child: Card(
              margin: EdgeInsets.zero,
              elevation: 0,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF161C24)
                  : Colors.white,

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),

                side: BorderSide(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF283442)
                      : const Color(0xFFEAE2D8),
                ),
              ),

              child: Padding(
                padding: const EdgeInsets.all(4),

                child: DeviceTile(
                  device: device,

                  onPressed: _busy || !device.isAvailable
                      ? null
                      : () => _run(
                          () => _service.requestConnection(device.endpointId),
                        ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // =========================================================
  // อุปกรณ์ที่เชื่อมต่อ
  // =========================================================

  Widget _buildConnectedDevices() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        _ListHeading(
          title: 'อุปกรณ์ที่เชื่อมต่อ',

          count: _service.connectedDevices.length,
        ),

        const SizedBox(height: 12),

        if (_service.connectedDevices.isEmpty)
          const _EmptyState(
            icon: Icons.link_off_rounded,

            title: 'ยังไม่มีการเชื่อมต่อ',

            description:
                'เชื่อมต่อกับอุปกรณ์ RescueLink ที่อยู่ใกล้เคียงเพื่อเริ่มสนทนา',
          ),

        for (final device in _service.connectedDevices)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),

            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF161C24)
                    : Colors.white,

                borderRadius: BorderRadius.circular(18),

                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF283442)
                      : const Color(0xFFEAE2D8),
                ),
              ),

              child: DeviceTile(
                device: device,

                onPressed: _busy
                    ? null
                    : () => _run(() => _service.disconnect(device.endpointId)),
              ),
            ),
          ),
      ],
    );
  }

  // =========================================================
  // การสนทนา
  // =========================================================

  Widget _buildConversations() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        _ListHeading(title: 'การสนทนาล่าสุด', count: _messages.peers.length),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            _messages.totalUnread == 0
                ? 'อ่านข้อความครบแล้ว'
                : 'ข้อความใหม่ ${_messages.totalUnread} ข้อความ • ${_messages.unreadCounts.length} การสนทนาที่ยังไม่ได้อ่าน',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),

        const SizedBox(height: 12),

        if (!_messages.ready)
          const _InfoState(
            icon: Icons.storage_outlined,

            text: 'กำลังโหลดข้อความที่บันทึกไว้...',
          ),

        if (_messages.error != null)
          Padding(
            padding: EdgeInsets.only(bottom: 10),

            child: _InfoState(
              icon: Icons.error_outline,

              text: 'ระบบข้อความ: ${_messages.error}',

              error: true,
            ),
          ),

        if (_messages.ready && _messages.peers.isEmpty)
          const _EmptyState(
            icon: Icons.chat_bubble_outline_rounded,

            title: 'ยังไม่มีการสนทนา',

            description:
                'เมื่อเชื่อมต่อกับโทรศัพท์อีกเครื่องแล้ว รายการสนทนาจะแสดงที่นี่',
          ),

        for (final peer in _messages.peers.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),

            child: _ConversationTile(
              name: peer.value,

              online: _messages.isOnline(peer.key),
              role: _messages.peerRoleLabel(peer.key),
              preview: _messages.conversationPreview(peer.key),
              unread: _messages.unreadCounts[peer.key] ?? 0,

              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ChatScreen(
                      service: _messages,
                      peerId: peer.key,
                      mediaService: _media,
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // =========================================================
  // อธิบายระบบออฟไลน์
  // =========================================================

  Widget _buildOfflineInfo() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(17),

      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF11221A) : const Color(0xFFEAF7F1),

        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF1C382C) : const Color(0xFFD4EFE3),
        ),
      ),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          const Icon(Icons.shield_outlined, color: Color(0xFF28845F)),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                const Text(
                  'เชื่อมต่อโดยตรงระหว่างอุปกรณ์',

                  style: TextStyle(fontWeight: FontWeight.w800),
                ),

                const SizedBox(height: 5),

                Text(
                  'RescueLink สามารถติดต่อสื่อสารกับโทรศัพท์ที่อยู่ใกล้เคียงได้โดยตรง โดยไม่ต้องใช้ข้อมูลมือถือหรือการเชื่อมต่ออินเทอร์เน็ต',

                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFF86EFAC)
                        : const Color(0xFF50675F),

                    height: 1.45,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),

      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF331414) : const Color(0xFFFFEEEE),

        borderRadius: BorderRadius.circular(14),

        border: Border.all(
          color: isDark ? const Color(0xFF5C2020) : const Color(0xFFFFCACA),
        ),
      ),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          const Icon(Icons.error_outline, color: Colors.red),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              'เกิดข้อผิดพลาด: ${_service.lastError}',

              style: const TextStyle(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================
// COMPONENTS
// ===========================================================

class _RescueLogo extends StatelessWidget {
  const _RescueLogo();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset(
        isDark
            ? 'assets/branding/rescuelink-logo-dark.png'
            : 'assets/branding/rescuelink-logo.png',
        width: 44,
        height: 44,
        fit: BoxFit.contain,
        semanticLabel: 'โลโก้ RescueLink',
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;

  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),

      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF161C24)
            : Colors.white,

        borderRadius: BorderRadius.circular(20),

        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF283442)
              : const Color(0xFFEAE2D8),
        ),
      ),

      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Container(
          width: 42,
          height: 42,

          decoration: BoxDecoration(
            color: const Color(0xFFFFEADB),

            borderRadius: BorderRadius.circular(13),
          ),

          child: Icon(icon, color: const Color(0xFFB94612), size: 21),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Text(
                title,

                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),

              const SizedBox(height: 3),

              Text(
                subtitle,

                style: TextStyle(
                  color: Colors.grey.shade600,

                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String text;
  final Color color;

  const _StatusChip({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),

      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),

        borderRadius: BorderRadius.circular(30),
      ),

      child: Text(
        text,

        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  final String name;
  final String value;
  final bool ok;

  const _PermissionRow({
    required this.name,
    required this.value,
    required this.ok,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),

      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.info_outline,

            size: 18,

            color: ok ? const Color(0xFF2E9B6F) : const Color(0xFFF0A63A),
          ),

          const SizedBox(width: 9),

          Expanded(
            child: Text(
              name,

              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),

          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool active;
  final VoidCallback? onTap;

  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: active
          ? (isDark ? const Color(0xFF3D2314) : const Color(0xFFFFEADB))
          : (isDark ? const Color(0xFF161C24) : Colors.white),

      borderRadius: BorderRadius.circular(20),

      child: InkWell(
        onTap: onTap,

        borderRadius: BorderRadius.circular(20),

        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),

          padding: const EdgeInsets.all(16),

          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),

            border: Border.all(
              color: active
                  ? const Color(0xFFB94612)
                  : (isDark
                        ? const Color(0xFF283442)
                        : const Color(0xFFEAE2D8)),

              width: active ? 1.5 : 1,
            ),
          ),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Container(
                width: 43,
                height: 43,

                decoration: BoxDecoration(
                  color: active
                      ? const Color(0xFFB94612)
                      : (isDark
                            ? const Color(0xFF382314)
                            : const Color(0xFFFFEADB)),

                  borderRadius: BorderRadius.circular(13),
                ),

                child: Icon(
                  icon,

                  color: active ? Colors.white : const Color(0xFFB94612),
                ),
              ),

              const SizedBox(height: 14),

              Text(
                title,

                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),

              const SizedBox(height: 5),

              Text(
                subtitle,

                style: TextStyle(
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : Colors.grey.shade600,

                  fontSize: 12,
                  height: 1.35,
                ),
              ),

              if (active) ...[
                const SizedBox(height: 12),

                const Row(
                  children: [
                    SizedBox(
                      width: 8,
                      height: 8,

                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),

                    SizedBox(width: 8),

                    Text(
                      'กำลังทำงาน',

                      style: TextStyle(
                        color: Color(0xFFB94612),

                        fontWeight: FontWeight.w700,

                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ListHeading extends StatelessWidget {
  final String title;
  final int count;

  const _ListHeading({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,

            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
          ),
        ),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),

          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF283442) : const Color(0xFFF0EBE3),

            borderRadius: BorderRadius.circular(30),
          ),

          child: Text(
            '$count',

            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),

      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161C24) : Colors.white,

        borderRadius: BorderRadius.circular(20),

        border: Border.all(
          color: isDark ? const Color(0xFF283442) : const Color(0xFFEAE2D8),
        ),
      ),

      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,

            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF382314) : const Color(0xFFFFEADB),

              shape: BoxShape.circle,
            ),

            child: Icon(icon, color: const Color(0xFFB94612), size: 29),
          ),

          const SizedBox(height: 14),

          Text(
            title,

            textAlign: TextAlign.center,

            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),

          const SizedBox(height: 6),

          Text(
            description,

            textAlign: TextAlign.center,

            style: TextStyle(
              color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
              height: 1.4,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final String name;
  final String role, preview;
  final int unread;
  final bool online;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.name,
    required this.online,
    required this.onTap,
    required this.role,
    required this.preview,
    required this.unread,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trimmed = name.trim();

    final firstLetter = trimmed.isNotEmpty
        ? trimmed.characters.first.toUpperCase()
        : 'R';

    return Material(
      color: isDark ? const Color(0xFF161C24) : Colors.white,

      borderRadius: BorderRadius.circular(18),

      child: InkWell(
        onTap: onTap,

        borderRadius: BorderRadius.circular(18),

        child: Container(
          padding: const EdgeInsets.all(14),

          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),

            border: Border.all(
              color: isDark ? const Color(0xFF283442) : const Color(0xFFEAE2D8),
            ),
          ),

          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 25,

                    backgroundColor: const Color(0xFFB94612),

                    child: Text(
                      firstLetter,

                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),

                  Positioned(
                    right: 0,
                    bottom: 0,

                    child: Container(
                      width: 13,
                      height: 13,

                      decoration: BoxDecoration(
                        color: online ? const Color(0xFF32AF79) : Colors.grey,

                        shape: BoxShape.circle,

                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF161C24)
                              : Colors.white,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      name,

                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      '$role • ${online ? 'ออนไลน์' : 'ออฟไลน์'}',

                      style: TextStyle(
                        color: online
                            ? const Color(0xFF2E9B6F)
                            : (isDark
                                  ? const Color(0xFF94A3B8)
                                  : Colors.grey.shade600),

                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: unread > 0
                            ? FontWeight.w700
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),

              if (unread > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Badge(
                    label: Text('$unread'),
                    child: const Icon(Icons.mark_chat_unread_outlined),
                  ),
                ),
              if (unread == 0)
                const Icon(
                  Icons.arrow_forward_ios_rounded,

                  size: 16,
                  color: Colors.grey,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoState extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool error;

  const _InfoState({
    required this.icon,
    required this.text,
    this.error = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),

      decoration: BoxDecoration(
        color: error
            ? (isDark ? const Color(0xFF331414) : const Color(0xFFFFEEEE))
            : (isDark ? const Color(0xFF161C24) : Colors.white),

        borderRadius: BorderRadius.circular(14),

        border: Border.all(
          color: error
              ? (isDark ? const Color(0xFF5C2020) : const Color(0xFFFFCCCC))
              : (isDark ? const Color(0xFF283442) : const Color(0xFFEAE2D8)),
        ),
      ),

      child: Row(
        children: [
          Icon(
            icon,
            color: error
                ? Colors.red
                : (isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
          ),

          const SizedBox(width: 10),

          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
