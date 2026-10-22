import 'messages_screen.dart';
import 'responder_screen.dart';
import 'incident_detail_screen.dart';
import '../services/app_preferences.dart';
import '../services/auth_service.dart';
import '../models/incoming_notice.dart';
import '../models/sos_alert.dart';
import '../widgets/location_button.dart';
import '../widgets/my_location_summary.dart';
import 'dart:async';
import 'settings_panel.dart';
import 'login_screen.dart';
import 'package:flutter/material.dart';

import '../services/nearby_service.dart';
import '../services/media_service.dart';
import '../services/message_service.dart';
import '../services/local_database_service.dart';
import '../services/permission_service.dart';
import '../services/connection_session.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/sos_location_service.dart';
import '../widgets/presence_list.dart';
import '../widgets/nearby_discovery_chip.dart';
import '../widgets/bundled_offline_map.dart';
import 'chat_screen.dart';
import 'sos_screen.dart';
import '../widgets/outbox_queue.dart';
import '../theme/rescue_theme.dart';
import '../services/member_service.dart';

class NearbyTestScreen extends StatefulWidget {
  const NearbyTestScreen({super.key, this.nearbyService, this.messageService});
  final NearbyService? nearbyService;
  final MessageService? messageService;

  @override
  State<NearbyTestScreen> createState() => _NearbyTestScreenState();
}

class _NearbyTestScreenState extends State<NearbyTestScreen>
    with WidgetsBindingObserver {
  late final NearbyService _service;

  late final TextEditingController _name;
  late final MessageService _messages;
  late final MediaService _media;

  bool _busy = false;
  int _tab = 0;

  bool _foreground = true;
  bool? _notificationsAllowed;
  bool _searchOnResume = true;
  bool _restartSearchAfterBusy = false;
  Timer? _noticeTimer;
  String? _authenticatedOwner;
  bool _exitingExpiredAccount = false;
  final List<IncomingNotice> _notices = [];
  IncomingNotice? _shownNotice;
  SosLocation? _me;
  bool _loadingGps = false;
  String? _gpsError;

  static const Color _primary = RescueTheme.orangeInk;
  static const Color _success = Color(0xFF2E9B6F);
  static const Color _warning = Color(0xFFF0A63A);

  _Palette get _p => _Palette.of(context);

  @override
  void initState() {
    super.initState();
    _authenticatedOwner = AuthService.instance.session?.userId;
    AuthService.instance.addListener(_accountChanged);
    _service = widget.nearbyService ?? NearbyService();
    _name = TextEditingController(text: _service.deviceName);

    final database =
        widget.messageService?.database ?? LocalDatabaseService.instance;

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
      getRelayPathForPeer: (peerId) => _messages.relayPathForPeer(peerId),
    );

    _messages =
        widget.messageService ??
        MessageService(
          nearbyService: _service,
          database: database,
          mediaService: _media,
        );

    _me = _messages.rescueLocation;
    _messages.addListener(_rememberRescueLocation);
    _messages.onNotice = _receiveNotice;
    _messages.onNoticeCancelled = _cancelNotice;
    unawaited(_refreshNotificationPermission());
    _messages
        .initialize()
        .then((_) async {
          if (!mounted) return;
          await _service.connectionSession.listenForNotifications(_openNotice);
        })
        .catchError((Object error) {
          debugPrint('Notification setup: $error');
        });
    AppPreferences.instance.addListener(_profileNameChanged);
    AppPreferences.instance
        .load()
        .then((_) => _profileNameChanged())
        .catchError((Object _) {});
    if (AuthService.instance.signedIn) {
      unawaited(() async {
        try {
          await SupabaseMemberRepository(AuthService.instance).read();
        } catch (_) {}
      }());
    }

    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_run(_service.startNearby));
    });
  }

  // =========================================================
  // Notice / Banner
  // =========================================================

  void _profileNameChanged() {
    unawaited(
      _service.connectionSession.updateChannelNames().catchError((
        Object error,
      ) {
        debugPrint('Notification channel names: $error');
      }),
    );
    final displayName = AppPreferences.instance.displayName;
    if (!mounted || displayName == null || displayName.trim().isEmpty) return;
    // Only the visible name changes. Persisted peer UUIDs and transport stay intact.
    _service.deviceName = displayName;
    _name.text = displayName;
  }

  void _accountChanged() {
    if (_authenticatedOwner == null ||
        _exitingExpiredAccount ||
        AuthService.instance.error == null ||
        AuthService.instance.session?.userId == _authenticatedOwner) {
      return;
    }
    _exitingExpiredAccount = true;
    unawaited(() async {
      try {
        await _service.stopAll().timeout(const Duration(seconds: 5));
      } catch (_) {}
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }());
  }

  Future<void> _refreshNotificationPermission() async {
    try {
      final allowed = await ConnectionSession.notificationsAllowed();
      if (mounted) setState(() => _notificationsAllowed = allowed);
    } catch (error) {
      debugPrint('Notification permission: $error');
    }
  }

  Future<void> _requestNotificationPermission() async {
    final status = await Permission.notification.request();
    if (status.isPermanentlyDenied || status.isRestricted) {
      await openAppSettings();
    }
    await _refreshNotificationPermission();
  }

  void _cancelNotice(String id) {
    _notices.removeWhere((notice) => notice.notificationId == id);
    if (_shownNotice?.notificationId == id) _dismissNotice();
    unawaited(
      _service.connectionSession.cancelNotice(id).catchError((Object error) {
        debugPrint('Cancel notification: $error');
      }),
    );
  }

  void _receiveNotice(IncomingNotice notice) {
    if (!mounted) return;
    if (!_foreground) {
      unawaited(
        _service.connectionSession
            .notify(
              notice,
              unreadCount: _messages.unreadCounts[notice.peerId] ?? 1,
            )
            .catchError((Object e) {
              debugPrint('Notification: $e');
            }),
      );
      return;
    }
    // Replace queued notices for the same conversation or incident.
    _notices.removeWhere(
      (pending) => pending.notificationId == notice.notificationId,
    );
    if (_shownNotice?.notificationId == notice.notificationId) {
      _noticeTimer?.cancel();
      ScaffoldMessenger.of(context).removeCurrentMaterialBanner();
      _shownNotice = null;
      _notices.insert(0, notice);
    } else {
      _notices.add(notice);
    }
    if (_shownNotice == null) _showNextNotice();
  }

  void _showNextNotice() {
    if (!mounted || _notices.isEmpty) return;
    final notice = _notices.removeAt(0);
    _shownNotice = notice;
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (notice.sos == null ? RescueTheme.navy : kSosRed).withValues(
              alpha: .10,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            notice.sos == null ? Icons.chat_bubble_outline : Icons.sos,
            size: 22,
            color: notice.sos == null
                ? Theme.of(context).colorScheme.onSurface
                : kSosRed,
          ),
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              notice.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              notice.preview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, height: 1.4, color: _p.muted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _dismissNotice();
              _openNotice(notice);
            },
            child: Text(notice.sos == null ? 'เปิดแชต' : 'ดู SOS'),
          ),
          IconButton(
            onPressed: _dismissNotice,
            tooltip: 'ปิด',
            icon: const Icon(Icons.close_rounded, size: 20),
          ),
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

  // =========================================================
  // Lifecycle / helpers
  // =========================================================

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _service.setForeground(false);
    } else if (state == AppLifecycleState.resumed) {
      _service.setForeground(true);
      unawaited(_refreshNotificationPermission());
      if (_searchOnResume) {
        if (_busy) {
          _restartSearchAfterBusy = true;
        } else {
          unawaited(_run(_service.startNearby));
        }
      }
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
        if (_restartSearchAfterBusy) {
          _restartSearchAfterBusy = false;
          if (_foreground && _searchOnResume) {
            unawaited(_run(_service.startNearby));
          }
        }
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
  // Permission
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
    AppPreferences.instance.removeListener(_profileNameChanged);
    AuthService.instance.removeListener(_accountChanged);
    WidgetsBinding.instance.removeObserver(this);
    _noticeTimer?.cancel();
    _service.connectionSession.detachNotifications();

    _messages.removeListener(_rememberRescueLocation);
    _messages.dispose();
    _media.dispose();
    _service.dispose();
    _name.dispose();

    super.dispose();
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _tab == 4 || _tab == 2
          ? null
          : AppBar(
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
      bottomNavigationBar: ListenableBuilder(
        listenable: _messages,
        builder: (context, _) => NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (value) => setState(() => _tab = value),
          destinations: [
            NavigationDestination(icon: Icon(Icons.radar), label: 'ใกล้ฉัน'),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: _messages.totalUnread > 0,
                label: Text(
                  _messages.totalUnread > 99
                      ? '99+'
                      : _messages.totalUnread.toString(),
                ),
                child: const Icon(Icons.chat_bubble_outline),
              ),
              label: 'ข้อความ',
            ),
            NavigationDestination(
              icon: CircleAvatar(
                backgroundColor: kSosRed,
                radius: 20,
                child: Icon(Icons.sos, color: Colors.white, size: 26),
              ),
              label: 'SOS',
            ),
            NavigationDestination(
              icon: Icon(Icons.outbox_outlined),
              label: 'คิวส่ง',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              label: 'ฉัน',
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([_service, _messages, _media]),
          builder: (context, _) {
            if (_tab == 1) {
              return MessagesScreen(
                service: _messages,
                onNearby: () => setState(() => _tab = 0),
              );
            }
            if (_tab == 2) return SosScreen(service: _messages, mainTab: true);
            if (_tab == 3) return _buildQueue();
            if (_tab == 4) return _buildSettingsTab();
            return _buildHomeTab();
          },
        ),
      ),
    );
  }

  Widget _buildSettingsTab() {
    return SettingsPanel(
      onResponder: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ResponderScreen(service: _messages),
        ),
      ),
      beforeAccountExit: () async {
        await _service.stopAll();
      },
      rescue: _messages.rescueMode,
      ready: _messages.ready && !_busy,
      onRescue: (value) => _run(() => _messages.setRescueMode(value)),
      onDevice: _openConnectionSettings,
      onConnection: _openConnectionSettings,
      onExit: () => _run(() async {
        await _service.stopAll();
        if (AuthService.instance.signedIn) {
          try {
            await AuthService.instance.signOut();
          } catch (_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('ออกจากระบบไม่สำเร็จ กรุณาลองใหม่'),
                ),
              );
            }
            return;
          }
        }
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }),
    );
  }

  // =========================================================
  // TAB: ใกล้ฉัน (สรุปการเชื่อมต่อ รายชื่อ และแผนที่)
  // =========================================================

  void _rememberRescueLocation() {
    final location = _messages.rescueLocation;
    if (mounted && location != null && location != _me) {
      setState(() => _me = location);
    }
  }

  Future<void> _locate() async {
    if (_loadingGps || _messages.rescueLocationLoading) return;
    setState(() {
      _loadingGps = true;
      _gpsError = null;
    });
    try {
      if (_messages.rescueMode) {
        final fix = await _messages.updateRescueLocation();
        if (mounted && fix != null) setState(() => _me = fix);
        return;
      }
      final fix = await SosLocationService(
        database: _messages.database,
      ).capture();
      if (!mounted) return;
      setState(() => _me = fix);
      if (_messages.rescueMode) await _messages.shareRescueLocation(fix);
    } catch (_) {
      if (mounted) {
        setState(
          () => _gpsError =
              'อ่านหรือแชร์ตำแหน่งไม่ได้ ตรวจสิทธิ์/GPS และโหมดกู้ภัย แล้วลองใหม่',
        );
      }
    } finally {
      if (mounted) setState(() => _loadingGps = false);
    }
  }

  void _openIncidentDetail(String peerId) {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            IncidentDetailScreen(service: _messages, peerId: peerId),
      ),
    );
  }

  Color _mapRoleColor({
    required bool sos,
    required bool rescue,
    bool isMe = false,
  }) {
    if (sos) return kSosRed;
    if (rescue) return RescueTheme.rescue;
    return isMe ? const Color(0xFF167A65) : Colors.grey;
  }

  Widget _buildHomeTab() {
    final now = DateTime.now().toUtc();
    final me =
        (_messages.rescueMode ? _messages.rescueLocation : null) ??
        _me ??
        _messages.mySos?.location;
    final locating = _loadingGps || _messages.rescueLocationLoading;
    final points = _messages.presence.entries
        .where((e) => e.key != _messages.myId && _messages.isReachable(e.key))
        .map(
          (e) => (
            id: e.key,
            state: e.value,
            location: e.value.sos?.isActiveAt(now) == true
                ? e.value.sos!.location
                : e.value.mapLocation,
          ),
        )
        .where((e) => e.location != null)
        .toList();
    final dark = _p.dark;

    return SingleChildScrollView(
      key: const ValueKey('nearby-home-scroll'),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_busy) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: const LinearProgressIndicator(minHeight: 3),
            ),
            const SizedBox(height: 10),
          ],
          _buildPresenceSection(dark),
          const SizedBox(height: 12),
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _p.accentSoft,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(
                        Icons.map_outlined,
                        size: 19,
                        color: Color(0xFFB94612),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'แผนที่และตำแหน่งของฉัน',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 280,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: BundledOfflineMap(
                      key: const ValueKey('full-home-map'),
                      focus: me,
                      fullScreen: true,
                      showControls: true,
                      onLocateMe: locating ? null : () => _locate(),
                      markers: [
                        for (final e in points)
                          OfflineMapMarker(
                            id: e.id,
                            label:
                                '${_messages.peers[e.id] ?? 'ไม่ทราบชื่อ'} • แตะดูรายละเอียด',
                            location: e.location!,
                            color: _mapRoleColor(
                              sos: e.state.sos?.isActiveAt(now) == true,
                              rescue: e.state.rescue,
                            ),
                            onTap: () => _openIncidentDetail(e.id),
                          ),
                        if (me != null)
                          OfflineMapMarker(
                            id: 'self',
                            label: 'ฉัน • พิกัดที่อ่านล่าสุด',
                            location: me,
                            color: _mapRoleColor(
                              sos: _messages.mySos?.isActiveAt(now) == true,
                              rescue: _messages.rescueMode,
                              isMe: true,
                            ),
                            isMe: true,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _buildColorLegend(dark),
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: locating ? null : () => _locate(),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFB94612),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    icon: locating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.my_location, size: 20),
                    label: Text(
                      locating
                          ? 'กำลังอ่าน GPS…'
                          : me == null
                          ? 'อ่านตำแหน่งของฉัน'
                          : 'อัปเดตตำแหน่งของฉัน',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                if (_gpsError != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: dark
                          ? const Color(0xFF331414)
                          : const Color(0xFFFFEEEE),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: dark
                            ? const Color(0xFF5C2020)
                            : const Color(0xFFFFCCCC),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 18,
                          color: dark
                              ? const Color(0xFFFFB4AB)
                              : const Color(0xFF9C2028),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _gpsError!,
                            style: TextStyle(
                              height: 1.4,
                              color: dark
                                  ? const Color(0xFFFFB4AB)
                                  : const Color(0xFF9C2028),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                MyLocationSummary(location: me),
                if (_messages.rescueMode) ...[
                  const SizedBox(height: 12),
                  _buildRescueModeActions(dark),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorLegend(bool dark) {
    final items = [
      (color: kSosRed, label: 'SOS'),
      (color: RescueTheme.rescue, label: 'กู้ภัย'),
      (
        color: _mapRoleColor(
          sos: _messages.mySos?.isActiveAt(DateTime.now().toUtc()) == true,
          rescue: _messages.rescueMode,
          isMe: true,
        ),
        label: 'ฉัน',
      ),
      (color: Colors.grey, label: 'ผู้ใช้ทั่วไป'),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1B222C) : const Color(0xFFFCF7F1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 16,
        runSpacing: 6,
        children: [
          for (final item in items)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: item.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: dark ? Colors.white70 : RescueTheme.navy,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildRescueModeActions(bool dark) {
    final status = _messages.rescueLocationLoading
        ? 'กำลังอ่าน GPS เพื่อแชร์ตำแหน่งกู้ภัยอัตโนมัติ…'
        : _messages.rescueLocationError ??
              (_messages.rescueLocation != null
                  ? 'แชร์ตำแหน่งกู้ภัยแล้ว • คนในเครือข่ายที่ได้รับพิกัดจะเห็นหมุดสีน้ำเงิน'
                  : 'ยังไม่มีพิกัดกู้ภัย กดอัปเดตตำแหน่งเพื่อแชร์ให้คนในเครือข่าย');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF0F2642) : const Color(0xFFEBF3FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: RescueTheme.rescue.withValues(alpha: .25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.shield_outlined,
            size: 20,
            color: RescueTheme.rescue,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'ใช้ปุ่มอัปเดตตำแหน่งด้านบนเพื่อแชร์พิกัดใหม่ • ปิดโหมดกู้ภัยเพื่อหยุดแชร์',
                  style: TextStyle(fontSize: 12, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresenceSection(bool dark) {
    final sosMode = _messages.mySos?.isActiveAt(DateTime.now().toUtc()) == true;
    final rescueMode = !sosMode && _messages.rescueMode;
    final active = _nearbyActive;
    final discoveryChip = NearbyDiscoveryChip(
      active: active,
      busy: _busy,
      onSettings: _openConnectionSettings,
      onStart: () => _run(() async {
        _searchOnResume = true;
        await _service.startNearby();
      }),
      onStop: () => _run(() async {
        _searchOnResume = false;
        await _service.stopAll();
      }),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_service.lastError != null) ...[
          _buildErrorCard(),
          const SizedBox(height: 12),
        ],
        if (!_permissionsReady) ...[
          _buildPermissionCard(),
          const SizedBox(height: 12),
        ],
        PresenceList(
          key: const ValueKey('nearby-primary-presence'),
          service: _messages,
          reachableOnly: true,
          flat: true,
          headerAction: sosMode || rescueMode ? null : discoveryChip,
          filter: sosMode
              ? PresenceFilter.rescue
              : rescueMode
              ? PresenceFilter.sos
              : PresenceFilter.all,
        ),
        if (sosMode || rescueMode) ...[
          const SizedBox(height: 8),
          PresenceList(
            key: const ValueKey('nearby-secondary-presence'),
            headerAction: discoveryChip,
            service: _messages,
            flat: true,
            excludeFilter: sosMode ? PresenceFilter.rescue : PresenceFilter.sos,
            reachableOnly: true,
          ),
        ],
      ],
    );
  }

  // =========================================================
  // หน้า "การเชื่อมต่อและสิทธิ์" (ข้อความอธิบายออฟไลน์อยู่ที่นี่ที่เดียว)
  // =========================================================

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
                if (_service.lastError != null) ...[
                  _buildErrorCard(),
                  const SizedBox(height: 16),
                ],
                _buildDeviceName(),
                const SizedBox(height: 14),
                _buildPermissionCard(),
                const SizedBox(height: 22),
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
    mediaFiles: {for (final media in _media.allMedia) media.mediaId: media},
    mediaUploads: {
      for (final media in _media.allMedia)
        if (_media.uploads.forMedia(media.mediaId) != null)
          media.mediaId: _media.uploads.forMedia(media.mediaId)!,
    },
    cloudSyncedMessageIds: _messages.cloudSyncedMessageIds,
    messages: _messages.messages
        .where((m) => m.senderId == _messages.myId)
        .toList(),
    peers: _messages.peers,
    ready: _messages.ready,
    busy: _busy,
    hasError: _messages.error != null,
    onRetry: () => _run(_messages.retry),
  );

  Widget _buildDeviceName() {
    final p = _p;
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
              fillColor: p.dark ? const Color(0xFF161C24) : RescueTheme.cream,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: p.line),
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

  Widget _buildPermissionCard() {
    final statuses = _service.permissions.statuses;
    final p = _p;

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
                      _searchOnResume = true;
                      await _service.startNearby();
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
          _PermissionRow(
            name: 'การแจ้งเตือน',
            value: _notificationsAllowed == null
                ? 'ยังไม่ได้ตรวจสอบ'
                : _notificationsAllowed!
                ? 'อนุญาตแล้ว'
                : 'ยังไม่อนุญาต',
            ok: _notificationsAllowed == true,
            action: _notificationsAllowed == true
                ? null
                : TextButton(
                    onPressed: _requestNotificationPermission,
                    child: const Text('ขอสิทธิ์ / เปิดตั้งค่า'),
                  ),
          ),
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
                  style: TextStyle(fontSize: 12, height: 1.4, color: p.muted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionMode() {
    final p = _p;
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
          style: TextStyle(color: p.muted),
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
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                      _searchOnResume = false;
                      await _service.stopAll();
                    }),
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
        _InfoState(icon: Icons.info_outline, text: _connectionStatusThai),
      ],
    );
  }

  // =========================================================
  // TAB: ข้อความ
  // =========================================================

  // =========================================================
  // อธิบายระบบออฟไลน์ (แสดงเฉพาะหน้าการเชื่อมต่อ)
  // =========================================================

  Widget _buildOfflineInfo() {
    final isDark = _p.dark;
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
                  'RescueLink ติดต่อกับโทรศัพท์ที่อยู่ใกล้เคียงได้โดยตรง โดยไม่ต้องใช้ข้อมูลมือถือหรืออินเทอร์เน็ต',
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
    final isDark = _p.dark;
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

/// สีกลางที่ใช้ซ้ำทั้งไฟล์ (โทนเดิม: ส้ม / กรมท่า / ครีม)
class _Palette {
  final bool dark;
  final Color card;
  final Color line;
  final Color muted;
  final Color accentSoft;

  const _Palette._({
    required this.dark,
    required this.card,
    required this.line,
    required this.muted,
    required this.accentSoft,
  });

  factory _Palette.of(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    return _Palette._(
      dark: d,
      card: d ? const Color(0xFF161C24) : Colors.white,
      line: d ? const Color(0xFF283442) : const Color(0xFFEAE2D8),
      muted: d ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
      accentSoft: d ? const Color(0xFF382314) : const Color(0xFFFFEADB),
    );
  }
}

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
    final p = _Palette.of(context);
    return Material(
      color: p.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: p.line),
      ),
      child: Padding(padding: const EdgeInsets.all(17), child: child),
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
    final p = _Palette.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: p.accentSoft,
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
                style: TextStyle(color: p.muted, fontSize: 12, height: 1.35),
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
          fontSize: 11.5,
        ),
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  final Widget? action;
  final String name;
  final String value;
  final bool ok;

  const _PermissionRow({
    required this.name,
    required this.value,
    required this.ok,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final p = _Palette.of(context);
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  textAlign: TextAlign.end,
                  style: TextStyle(color: p.muted, fontSize: 12),
                ),
                ?action,
              ],
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
    final p = _Palette.of(context);
    return Material(
      color: active
          ? (p.dark ? const Color(0xFF3D2314) : const Color(0xFFFFEADB))
          : p.card,
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
              color: active ? const Color(0xFFB94612) : p.line,
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
                  color: active ? const Color(0xFFB94612) : p.accentSoft,
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
                style: TextStyle(color: p.muted, fontSize: 12, height: 1.35),
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

class _InfoState extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool error = false;

  const _InfoState({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final p = _Palette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: error
            ? (p.dark ? const Color(0xFF331414) : const Color(0xFFFFEEEE))
            : p.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: error
              ? (p.dark ? const Color(0xFF5C2020) : const Color(0xFFFFCCCC))
              : p.line,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: error ? Colors.red : p.muted, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(height: 1.4, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
