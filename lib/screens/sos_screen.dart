import 'package:flutter/material.dart';
import '../models/message_model.dart';
import '../models/sos_alert.dart';
import '../services/message_service.dart';
import '../services/sos_location_service.dart';
import 'chat_screen.dart';
import '../widgets/presence_list.dart';
import '../widgets/location_button.dart';
import '../widgets/sos_radar.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key, required this.service});
  final MessageService service;
  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _details = TextEditingController();
  final _people = TextEditingController(text: '1');
  EmergencyType _category = EmergencyType.medical;
  SosLocation? _location;
  final _recipients = <String>{};
  bool _busy = false;
  bool _readingLocation = false;
  String? _error;
  bool _rescueTab = false;
  static const _ink = Color(0xFF102D43);
  static const _muted = Color(0xFF687782);
  static const _orange = Color(0xFFB94612);

  @override
  void initState() {
    super.initState();
    _rescueTab = widget.service.rescueMode;
    final alert = widget.service.mySos;
    _name.text = alert?.name ?? widget.service.nearbyService.deviceName;
    if (alert != null) {
      _details.text = alert.details;
      _people.text = '${alert.people}';
      _category = alert.category;
      _location = alert.location;
      _recipients.addAll(widget.service.sosRecipients);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _details.dispose();
    _people.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันข้อมูล SOS'),
        content: SingleChildScrollView(
          child: Text(
            'ประกาศสถานะให้ทุกเครื่องที่เชื่อมต่อ รวมเครื่องที่เชื่อมต่อภายหลัง'
            '\nผู้รับข้อความเพิ่มเติม: ${_recipients.map((id) => widget.service.peers[id] ?? id).join(', ')}'
            '\n${_name.text} • ${_people.text} คน\n${_category.label}\n${_details.text}'
            '\n\n${_location?.summary ?? 'ส่งโดยไม่แนบพิกัด'}'
            '\n\nหากออฟไลน์ ระบบจะเก็บไว้ส่งเมื่อเชื่อมต่อผู้รับอีกครั้ง',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('กลับไปแก้ไข'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ยืนยันส่ง SOS'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(
      () => widget.service.publishSos(
        name: _name.text,
        people: int.parse(_people.text),
        category: _category,
        details: _details.text,
        recipients: Set.of(_recipients),
        location: _location,
      ),
    );
  }

  Widget _requestCard(MessageModel message) {
    final alert = SosAlert.fromJson(message.text);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              alert.active
                  ? 'ประวัติข้อความขอความช่วยเหลือ'
                  : 'ยกเลิกโดยผู้ส่ง',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SelectableText(alert.summary),
            if (alert.location != null)
              LocationButton(location: alert.location!),
            Text('อัปเดต: ${alert.updatedAt.toLocal()}'),
            Text(
              widget.service.isOnline(message.senderId)
                  ? 'ผู้ส่งเชื่อมต่ออยู่'
                  : 'ผู้ส่งออฟไลน์ • ข้อมูลล่าสุดที่ได้รับ',
            ),
            TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => ChatScreen(
                    service: widget.service,
                    peerId: message.senderId,
                  ),
                ),
              ),
              icon: const Icon(Icons.chat_outlined),
              label: const Text('แชตกับผู้ขอความช่วยเหลือ'),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _input(String label, {String? hint, IconData? icon}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon, size: 20, color: _muted),
      filled: true,
      fillColor: isDark ? const Color(0xFF161C24) : const Color(0xFFFCF8F1),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 18,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF283442) : const Color(0xFFEAE2D8),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF283442) : const Color(0xFFEAE2D8),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _orange, width: 1.5),
      ),
    );
  }

  Widget _section(
    String number,
    String title,
    String subtitle,
    List<Widget> children,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161C24) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF283442) : const Color(0xFFF0EBE3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF382314)
                      : const Color(0xFFFFEDE6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  number,
                  style: const TextStyle(
                    color: _orange,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: isDark ? const Color(0xFFF1F5F9) : _ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: _muted, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  IconData _categoryIcon(EmergencyType value) => switch (value) {
    EmergencyType.medical => Icons.medical_services_outlined,
    EmergencyType.trapped => Icons.person_pin_circle_outlined,
    EmergencyType.supplies => Icons.water_drop_outlined,
    EmergencyType.other => Icons.sos_rounded,
  };

  Widget _categoryPicker() => LayoutBuilder(
    builder: (context, constraints) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final largeText = MediaQuery.textScalerOf(context).scale(14) > 19;
      final width = largeText || constraints.maxWidth < 270
          ? constraints.maxWidth
          : (constraints.maxWidth - 10) / 2;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final type in EmergencyType.values)
            SizedBox(
              width: width,
              child: Semantics(
                selected: _category == type,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.all(14),
                    foregroundColor: _category == type
                        ? _orange
                        : (isDark ? const Color(0xFFF1F5F9) : _ink),
                    backgroundColor: _category == type
                        ? (isDark ? const Color(0xFF3D2314) : const Color(0xFFFFEADB))
                        : (isDark ? const Color(0xFF161C24) : Colors.white),
                    side: BorderSide(
                      color: _category == type
                          ? _orange
                          : (isDark ? const Color(0xFF283442) : const Color(0xFFEAE2D8)),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _busy
                      ? null
                      : () => setState(() => _category = type),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(_categoryIcon(type), size: 25),
                      const SizedBox(height: 10),
                      Text(
                        type.label,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );

  Future<void> _readLocation() => _run(() async {
    setState(() => _readingLocation = true);
    try {
      final fix = await SosLocationService().capture();
      if (mounted) setState(() => _location = fix);
    } finally {
      if (mounted) setState(() => _readingLocation = false);
    }
  });

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.service,
    builder: (context, _) {
      final service = widget.service;
      final current = service.mySos;
      final active = current?.active == true;
      final deliveries = service.messages
          .where(
            (m) =>
                m.senderId == service.myId &&
                m.type == MessageType.sos &&
                current != null &&
                SosAlert.fromJson(m.text).incidentId == current.incidentId &&
                SosAlert.fromJson(m.text).revision == current.revision,
          )
          .toList();
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final inkColor = isDark ? const Color(0xFFF1F5F9) : _ink;
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0C1017) : const Color(0xFFFCF8F1),
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF0C1017) : const Color(0xFFFCF8F1),
          surfaceTintColor: Colors.transparent,
          foregroundColor: inkColor,
          title: const Text(
            'ศูนย์ช่วยเหลือ',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E2631) : const Color(0xFFF0EBE3),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _tabButton(
                              'ขอความช่วยเหลือ',
                              false,
                              Icons.sos_rounded,
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: _tabButton(
                              'หน่วยกู้ภัย',
                              true,
                              Icons.shield_outlined,
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_busy) const LinearProgressIndicator(color: _orange),
                    if (_error != null || service.error != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF381815) : const Color(0xFFFFE8E4),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          _error ?? service.error!,
                          style: TextStyle(
                            color: isDark ? const Color(0xFFFF897D) : const Color(0xFF9B3021),
                          ),
                        ),
                      ),
                    if (_rescueTab) ...[
                      Text(
                        'พร้อมเป็นคนช่วย',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: inkColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'ติดตามคำขอและติดต่อผู้ที่ต้องการความช่วยเหลือ',
                        style: TextStyle(color: _muted, height: 1.5),
                      ),
                      const SizedBox(height: 20),
                      Material(
                        color: isDark ? const Color(0xFF161C24) : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        clipBehavior: Clip.antiAlias,
                        child: SwitchListTile(
                          contentPadding: const EdgeInsets.all(16),
                          activeThumbColor: const Color(0xFF2563EB),
                          title: const Text(
                            'พร้อมช่วยเหลือ',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: const Text(
                            'ประกาศสถานะให้เครื่องที่เชื่อมต่อเห็น',
                          ),
                          value: service.rescueMode,
                          onChanged: _busy || !service.ready
                              ? null
                              : (value) =>
                                    _run(() => service.setRescueMode(value)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (service.rescueMode) SosRadar(service: service),
                      PresenceList(service: service),
                      if (service.rescueMode) ...[
                        const SizedBox(height: 16),
                        if (service.receivedSos.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('ยังไม่มี SOS ที่ส่งมาถึงเครื่องนี้'),
                          ),
                        ...service.receivedSos.map(_requestCard),
                        const Text(
                          'สถานะรับข้อความไม่ได้หมายถึงมีผู้ช่วยเหลือรับงานแล้ว',
                          style: TextStyle(color: _muted, fontSize: 12),
                        ),
                      ],
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark
                                ? const [Color(0xFF2C1E17), Color(0xFF1E1714)]
                                : const [Color(0xFFFFE9DC), Color(0xFFFFF5EC)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: isDark
                              ? Border.all(color: const Color(0xFF4A2B20))
                              : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF3D251A)
                                        : Colors.white.withValues(alpha: .8),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.sos_rounded,
                                    color: _orange,
                                    size: 30,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'ทุกการขอความช่วยเหลือสำคัญ',
                                    style: TextStyle(
                                      color: isDark ? const Color(0xFFFF9E7D) : const Color(0xFF934025),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              active
                                  ? 'SOS ของคุณเปิดอยู่'
                                  : 'ให้คนใกล้ตัวช่วยคุณ',
                              style: TextStyle(
                                color: inkColor,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'ระบุเหตุและตำแหน่ง เพื่อให้คนที่เชื่อมต่อ\nเข้าใจว่าคุณต้องการความช่วยเหลืออะไร',
                              style: TextStyle(
                                color: isDark ? const Color(0xFFC4B5A5) : const Color(0xFF805E4F),
                                fontSize: 13,
                                height: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (current != null)
                        _section(
                          '✓',
                          active ? 'บันทึกคำขอแล้ว' : 'บันทึกการยกเลิกแล้ว',
                          'ยังไม่ใช่การตอบรับจากเจ้าหน้าที่',
                          [
                            for (final m in deliveries)
                              Text(
                                '${service.peers[m.receiverId] ?? m.receiverId}: ${switch (m.status) {
                                  MessageStatus.pending => 'รอเชื่อมต่อเพื่อส่ง',
                                  MessageStatus.sent => 'ส่งแล้ว รอเครื่องปลายทางยืนยัน',
                                  _ => 'เครื่องปลายทางบันทึกแล้ว',
                                }}',
                              ),
                          ],
                        ),
                      Form(
                        key: _form,
                        child: Column(
                          children: [
                            _section(
                              '01',
                              'เกิดอะไรขึ้น?',
                              'เลือกประเภทเหตุที่ใกล้เคียงที่สุด',
                              [
                                _categoryPicker(),
                                const SizedBox(height: 18),
                                TextFormField(
                                  controller: _details,
                                  enabled: !_busy,
                                  maxLength: 1000,
                                  minLines: 3,
                                  maxLines: 5,
                                  decoration: _input(
                                    'รายละเอียดเพิ่มเติม',
                                    hint: 'เช่น ติดอยู่ชั้น 2 ต้องการน้ำดื่ม',
                                  ),
                                ),
                              ],
                            ),
                            _section(
                              '02',
                              'ข้อมูลผู้ขอความช่วยเหลือ',
                              'ช่วยให้ผู้รับรู้ว่ากำลังช่วยใคร',
                              [
                                TextFormField(
                                  controller: _name,
                                  enabled: !_busy,
                                  maxLength: 80,
                                  decoration: _input(
                                    'ชื่อผู้ขอความช่วยเหลือ',
                                    icon: Icons.person_outline,
                                  ),
                                  validator: (v) =>
                                      v == null || v.trim().isEmpty
                                      ? 'กรอกชื่อ'
                                      : null,
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: _people,
                                  enabled: !_busy,
                                  keyboardType: TextInputType.number,
                                  decoration: _input(
                                    'จำนวนคนที่ต้องการความช่วยเหลือ',
                                    icon: Icons.people_outline,
                                  ),
                                  validator: (v) {
                                    final n = int.tryParse(v ?? '');
                                    return n == null || n < 1 || n > 999
                                        ? 'ระบุจำนวน 1–999 คน'
                                        : null;
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      _section(
                        '03',
                        'คุณอยู่ที่ไหน?',
                        'แนบพิกัดเพื่อให้ค้นหาคุณได้ง่ายขึ้น',
                        [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF14221E) : const Color(0xFFF2F6F5),
                              borderRadius: BorderRadius.circular(16),
                              border: isDark
                                  ? Border.all(color: const Color(0xFF1F3830))
                                  : null,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  color: Color(0xFF38776B),
                                  size: 28,
                                ),
                                const SizedBox(height: 10),
                                SelectableText(
                                  _location?.summary ?? 'ยังไม่ได้แนบพิกัด',
                                ),
                                if (_location == null)
                                  const Text(
                                    'ส่งคำขอโดยไม่แนบพิกัดได้',
                                    style: TextStyle(
                                      color: _muted,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (_readingLocation)
                            const Padding(
                              padding: EdgeInsets.only(top: 12),
                              child: Text(
                                'กำลังอ่านตำแหน่ง สูงสุด 60 วินาที กรุณาอยู่บริเวณโล่งและเปิดหน้านี้ค้างไว้',
                              ),
                            ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _busy ? null : _readLocation,
                              icon: const Icon(Icons.my_location),
                              label: const Text('ใช้ตำแหน่งปัจจุบัน'),
                            ),
                          ),
                          if (_location != null) ...[
                            LocationButton(location: _location!),
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => setState(() => _location = null),
                              child: const Text('ไม่แนบพิกัด'),
                            ),
                          ],
                        ],
                      ),
                      Material(
                        color: isDark ? const Color(0xFF161C24) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        clipBehavior: Clip.antiAlias,
                        child: ExpansionTile(
                          shape: const Border(),
                          collapsedShape: const Border(),
                          leading: const Icon(
                            Icons.group_add_outlined,
                            color: _muted,
                          ),
                          title: const Text(
                            'ผู้รับเพิ่มเติม',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            active
                                ? 'ยกเลิก SOS ก่อนเปลี่ยนผู้รับ'
                                : 'ไม่จำเป็นต้องเลือก',
                            style: const TextStyle(fontSize: 12, color: _muted),
                          ),
                          children: [
                            if (service.peers.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(
                                  'คำขอจะประกาศเมื่อเชื่อมต่อเครื่องอื่น',
                                ),
                              ),
                            for (final peer in service.peers.entries)
                              CheckboxListTile(
                                title: Text(peer.value),
                                subtitle: Text(
                                  service.isOnline(peer.key)
                                      ? 'เชื่อมต่ออยู่'
                                      : 'ออฟไลน์ — รอส่งเมื่อเชื่อมต่อ',
                                ),
                                value: _recipients.contains(peer.key),
                                onChanged: _busy || active
                                    ? null
                                    : (value) => setState(() {
                                        if (value == true) {
                                          _recipients.add(peer.key);
                                        } else {
                                          _recipients.remove(peer.key);
                                        }
                                      }),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Color(0xFFC94B2B),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 19,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          onPressed: _busy || !service.ready ? null : _send,
                          icon: const Icon(Icons.sos_rounded),
                          label: Text(
                            active ? 'อัปเดต SOS' : 'ตรวจข้อมูลและส่ง SOS',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: Text(
                          'คุณจะได้ตรวจสอบข้อมูลอีกครั้งก่อนส่ง',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: _muted),
                        ),
                      ),
                      if (active)
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFB63432),
                          ),
                          onPressed: _busy
                              ? null
                              : () => _run(service.cancelSos),
                          child: const Text('ยกเลิก SOS และแจ้งผู้รับเดิม'),
                        ),
                    ],
                    const SizedBox(height: 18),
                    const ExpansionTile(
                      shape: Border(),
                      collapsedShape: Border(),
                      title: Text(
                        'การส่ง SOS ทำงานอย่างไร?',
                        style: TextStyle(fontSize: 12, color: _muted),
                      ),
                      children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Text(
                            'ใช้งานได้โดยไม่ต้องมีอินเทอร์เน็ต แต่ต้องเชื่อมต่ออุปกรณ์ใกล้เคียงก่อน '
                            'สถานะส่งซ้ำทุก 5 วินาที และหมดอายุเมื่อไม่ได้รับ 30 วินาที '
                            'การได้รับข้อความไม่ใช่การยืนยันรับช่วยเหลือ',
                            style: TextStyle(
                              fontSize: 12,
                              color: _muted,
                              height: 1.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _tabButton(
    String label,
    bool rescue,
    IconData icon, {
    bool isDark = false,
  }) {
    final selected = _rescueTab == rescue;
    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: selected
            ? (isDark ? Colors.white : _ink)
            : (isDark ? const Color(0xFF94A3B8) : _muted),
        backgroundColor: selected
            ? (isDark ? const Color(0xFF283442) : Colors.white)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: _busy ? null : () => setState(() => _rescueTab = rescue),
      child: Semantics(
        selected: selected,
        child: Column(
          children: [
            Icon(
              icon,
              size: 22,
              color: selected
                  ? (rescue ? const Color(0xFF2563EB) : _orange)
                  : (isDark ? const Color(0xFF94A3B8) : _muted),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
