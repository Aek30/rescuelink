import 'package:flutter/material.dart';

import '../services/nearby_service.dart';
import '../services/message_service.dart';
import '../services/permission_service.dart';
import '../widgets/device_tile.dart';
import 'chat_screen.dart';

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

  bool _busy = false;

  static const Color _primary = Color(0xFF24599A);
  static const Color _background = Color(0xFFF5F7FB);
  static const Color _success = Color(0xFF2E9B6F);
  static const Color _warning = Color(0xFFF0A63A);

  @override
  void initState() {
    super.initState();

    _name = TextEditingController(text: _service.deviceName);

    _messages = MessageService(nearbyService: _service);

    _messages.initialize();

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
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

    _messages.dispose();
    _service.dispose();
    _name.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,

      appBar: AppBar(
        backgroundColor: _background,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 18,

        title: const Row(
          children: [
            _RescueLogo(),

            SizedBox(width: 10),

            Text(
              'RescueLink',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22),
            ),
          ],
        ),

        actions: [
          IconButton(
            tooltip: 'ตั้งค่าแอป',
            onPressed: _busy ? null : _openSettings,
            icon: const Icon(Icons.settings_outlined),
          ),

          const SizedBox(width: 8),
        ],
      ),

      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([_service, _messages]),

          builder: (context, _) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 36),

              children: [
                _buildHeroCard(),

                if (_busy) ...[
                  const SizedBox(height: 14),
                  const LinearProgressIndicator(),
                ],

                if (_service.lastError != null) ...[
                  const SizedBox(height: 14),
                  _buildErrorCard(),
                ],

                const SizedBox(height: 24),

                _buildDeviceName(),

                const SizedBox(height: 24),

                _buildPermissionCard(),

                const SizedBox(height: 28),

                _buildConnectionMode(),

                const SizedBox(height: 30),

                _buildNearbyDevices(),

                const SizedBox(height: 30),

                _buildConnectedDevices(),

                const SizedBox(height: 30),

                _buildConversations(),

                const SizedBox(height: 30),

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

  // =========================================================
  // กล่องสถานะหลัก
  // =========================================================

  Widget _buildHeroCard() {
    final connectedCount = _service.connectedDevices.length;

    String title;
    String description;
    String status;
    IconData icon;

    if (connectedCount > 0) {
      title = 'เชื่อมต่อแล้ว';

      description = connectedCount == 1
          ? 'กำลังเชื่อมต่อกับอุปกรณ์ใกล้เคียง 1 เครื่อง'
          : 'กำลังเชื่อมต่อกับอุปกรณ์ใกล้เคียง $connectedCount เครื่อง';

      status = 'เชื่อมต่อ';

      icon = Icons.link_rounded;
    } else if (_service.isDiscovering) {
      title = 'กำลังค้นหาอุปกรณ์';

      description = 'กำลังค้นหาอุปกรณ์ RescueLink ที่อยู่ใกล้คุณ';

      status = 'กำลังค้นหา';

      icon = Icons.radar_rounded;
    } else if (_service.isAdvertising) {
      title = 'พร้อมให้อุปกรณ์อื่นค้นพบ';

      description = 'โทรศัพท์ RescueLink เครื่องอื่นสามารถค้นหาเครื่องนี้ได้';

      status = 'พร้อมค้นพบ';

      icon = Icons.cell_tower_rounded;
    } else {
      title = 'พร้อมเชื่อมต่อแบบออฟไลน์';

      description = 'ติดต่อกับอุปกรณ์ใกล้เคียงได้โดยไม่ต้องใช้อินเทอร์เน็ต';

      status = 'ออฟไลน์';

      icon = Icons.shield_outlined;
    }

    return Container(
      padding: const EdgeInsets.all(22),

      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF174C8F), Color(0xFF3378C5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),

        borderRadius: BorderRadius.circular(26),

        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),

                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),

                  borderRadius: BorderRadius.circular(16),
                ),

                child: Icon(icon, color: Colors.white, size: 26),
              ),

              const Spacer(),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),

                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),

                  borderRadius: BorderRadius.circular(30),
                ),

                child: Row(
                  mainAxisSize: MainAxisSize.min,

                  children: [
                    Container(
                      width: 8,
                      height: 8,

                      decoration: BoxDecoration(
                        color: _nearbyActive || connectedCount > 0
                            ? const Color(0xFF77F2B5)
                            : Colors.white70,

                        shape: BoxShape.circle,
                      ),
                    ),

                    const SizedBox(width: 7),

                    Text(
                      status,

                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          Text(
            title,

            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 7),

          Text(
            description,

            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),

              height: 1.4,
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 22),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),

            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.13),

              borderRadius: BorderRadius.circular(12),
            ),

            child: Row(
              mainAxisSize: MainAxisSize.min,

              children: [
                const Icon(
                  Icons.smartphone_rounded,
                  color: Colors.white,
                  size: 17,
                ),

                const SizedBox(width: 7),

                Flexible(
                  child: Text(
                    _name.text,

                    overflow: TextOverflow.ellipsis,

                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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

              fillColor: const Color(0xFFF7F8FB),

              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),

                borderSide: BorderSide.none,
              ),

              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),

                borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
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

              const Padding(
                padding: EdgeInsets.only(bottom: 8),

                child: Text(
                  'ควรเปิด Bluetooth, Wi-Fi และบริการตำแหน่งเพื่อให้การค้นหาอุปกรณ์ทำงานได้ตามปกติ',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Color(0xFF666666),
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
            color: Colors.white,

            borderRadius: BorderRadius.circular(14),

            border: Border.all(color: const Color(0xFFE5E8ED)),
          ),

          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Icon(Icons.info_outline, size: 19, color: Colors.grey.shade600),

              const SizedBox(width: 10),

              Expanded(
                child: Text(
                  _connectionStatusThai,

                  style: TextStyle(
                    color: Colors.grey.shade700,
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
              color: Colors.white,

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),

                side: const BorderSide(color: Color(0xFFE5E8ED)),
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
                color: Colors.white,

                borderRadius: BorderRadius.circular(18),

                border: Border.all(color: const Color(0xFFE5E8ED)),
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

              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        ChatScreen(service: _messages, peerId: peer.key),
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
    return Container(
      padding: const EdgeInsets.all(17),

      decoration: BoxDecoration(
        color: const Color(0xFFEAF7F1),

        borderRadius: BorderRadius.circular(18),
      ),

      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Icon(Icons.shield_outlined, color: Color(0xFF28845F)),

          SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  'เชื่อมต่อโดยตรงระหว่างอุปกรณ์',

                  style: TextStyle(fontWeight: FontWeight.w800),
                ),

                SizedBox(height: 5),

                Text(
                  'RescueLink สามารถติดต่อสื่อสารกับโทรศัพท์ที่อยู่ใกล้เคียงได้โดยตรง โดยไม่ต้องใช้ข้อมูลมือถือหรือการเชื่อมต่ออินเทอร์เน็ต',

                  style: TextStyle(
                    color: Color(0xFF50675F),

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
    return Container(
      padding: const EdgeInsets.all(14),

      decoration: BoxDecoration(
        color: const Color(0xFFFFEEEE),

        borderRadius: BorderRadius.circular(14),

        border: Border.all(color: const Color(0xFFFFCACA)),
      ),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Icon(Icons.error_outline, color: Colors.red),

          SizedBox(width: 10),

          Expanded(
            child: Text(
              'เกิดข้อผิดพลาด: ${_service.lastError}',

              style: TextStyle(height: 1.4),
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
    return Container(
      width: 39,
      height: 39,

      decoration: BoxDecoration(
        color: const Color(0xFF24599A),

        borderRadius: BorderRadius.circular(12),
      ),

      child: const Icon(
        Icons.cell_tower_rounded,
        color: Colors.white,
        size: 21,
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
        color: Colors.white,

        borderRadius: BorderRadius.circular(20),

        border: Border.all(color: const Color(0xFFE5E8ED)),
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
            color: const Color(0xFFEAF2FC),

            borderRadius: BorderRadius.circular(13),
          ),

          child: Icon(icon, color: const Color(0xFF24599A), size: 21),
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
    return Material(
      color: active ? const Color(0xFFEAF2FC) : Colors.white,

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
              color: active ? const Color(0xFF24599A) : const Color(0xFFE5E8ED),

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
                      ? const Color(0xFF24599A)
                      : const Color(0xFFEAF2FC),

                  borderRadius: BorderRadius.circular(13),
                ),

                child: Icon(
                  icon,

                  color: active ? Colors.white : const Color(0xFF24599A),
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
                  color: Colors.grey.shade600,

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
                        color: Color(0xFF24599A),

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
            color: const Color(0xFFE8EBF0),

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
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(20),

        border: Border.all(color: const Color(0xFFE5E8ED)),
      ),

      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,

            decoration: const BoxDecoration(
              color: Color(0xFFEAF2FC),

              shape: BoxShape.circle,
            ),

            child: Icon(icon, color: const Color(0xFF24599A), size: 29),
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
              color: Colors.grey.shade600,
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
  final bool online;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.name,
    required this.online,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();

    final firstLetter = trimmed.isNotEmpty
        ? trimmed.characters.first.toUpperCase()
        : 'R';

    return Material(
      color: Colors.white,

      borderRadius: BorderRadius.circular(18),

      child: InkWell(
        onTap: onTap,

        borderRadius: BorderRadius.circular(18),

        child: Container(
          padding: const EdgeInsets.all(14),

          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),

            border: Border.all(color: const Color(0xFFE5E8ED)),
          ),

          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 25,

                    backgroundColor: const Color(0xFF24599A),

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

                        border: Border.all(color: Colors.white, width: 2),
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
                      online
                          ? 'เชื่อมต่อแล้ว • แตะเพื่อสนทนา'
                          : 'ออฟไลน์ • ยังดูประวัติข้อความได้',

                      style: TextStyle(
                        color: online
                            ? const Color(0xFF2E9B6F)
                            : Colors.grey.shade600,

                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

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
    return Container(
      padding: const EdgeInsets.all(14),

      decoration: BoxDecoration(
        color: error ? const Color(0xFFFFEEEE) : Colors.white,

        borderRadius: BorderRadius.circular(14),

        border: Border.all(
          color: error ? const Color(0xFFFFCCCC) : const Color(0xFFE5E8ED),
        ),
      ),

      child: Row(
        children: [
          Icon(icon, color: error ? Colors.red : Colors.grey.shade600),

          const SizedBox(width: 10),

          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
