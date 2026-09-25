import 'package:flutter/material.dart';
import '../models/message_model.dart';
import '../models/sos_alert.dart';
import '../services/message_service.dart';
import '../services/sos_location_service.dart';
import 'chat_screen.dart';
import '../widgets/presence_list.dart';
import '../widgets/location_button.dart';

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

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.service,
    builder: (context, _) {
      final service = widget.service;
      final active = service.mySos?.active == true;
      final current = service.mySos;
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
      return Scaffold(
        appBar: AppBar(title: const Text('SOS / หน่วยช่วยเหลือ')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'ประกาศ SOS / Rescue ให้ทุกเครื่องที่เชื่อมต่อโดยตรง เปิดแอปค้างไว้และเชื่อมต่อจากหน้าหลักก่อน สถานะส่งซ้ำทุก 5 วินาที และหมดอายุเมื่อไม่ได้รับ 30 วินาที',
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Rescue Mode — ประกาศพร้อมช่วยเหลือ'),
                subtitle: Text(
                  'รับ SOS แล้ว ${service.receivedSos.where((m) => SosAlert.fromJson(m.text).active).length} รายการที่ยังไม่ยกเลิก',
                ),
                value: service.rescueMode,
                onChanged: _busy
                    ? null
                    : (value) => _run(() => service.setRescueMode(value)),
              ),
              if (_busy) const LinearProgressIndicator(),
              if (_readingLocation)
                const Text(
                  'กำลังอ่านตำแหน่ง สูงสุด 60 วินาที กรุณาอยู่บริเวณโล่งและเปิดหน้านี้ค้างไว้',
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              if (service.error != null) Text(service.error!),
              PresenceList(service: service),
              if (service.rescueMode) ...[
                const Text(
                  'สถานะรับข้อความไม่ได้หมายถึงมีผู้ช่วยเหลือรับงานแล้ว',
                ),
                if (service.receivedSos.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('ยังไม่มี SOS ที่ส่งมาถึงเครื่องนี้'),
                  ),
                ...service.receivedSos.map(_requestCard),
              ],
              ...[
                Text(
                  active ? 'SOS ของฉัน — เปิดอยู่' : 'ขอความช่วยเหลือ',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                if (current != null) ...[
                  Text(
                    current.active ? 'บันทึกคำขอแล้ว' : 'บันทึกการยกเลิกแล้ว',
                  ),
                  for (final m in deliveries)
                    Text(
                      '${service.peers[m.receiverId] ?? m.receiverId}: ${switch (m.status) {
                        MessageStatus.pending => 'รอเชื่อมต่อเพื่อส่ง',
                        MessageStatus.sent => 'ส่งแล้ว รอเครื่องปลายทางยืนยัน',
                        _ => 'เครื่องปลายทางบันทึกแล้ว',
                      }}',
                    ),
                  const Text('การยืนยันนี้ไม่ใช่การตอบรับจากเจ้าหน้าที่'),
                ],
                const SizedBox(height: 16),
                Form(
                  key: _form,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _name,
                        enabled: !_busy,
                        maxLength: 80,
                        decoration: const InputDecoration(
                          labelText: 'ชื่อผู้ขอความช่วยเหลือ',
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'กรอกชื่อ' : null,
                      ),
                      DropdownButtonFormField<EmergencyType>(
                        initialValue: _category,
                        decoration: const InputDecoration(
                          labelText: 'ประเภทเหตุฉุกเฉิน',
                        ),
                        items: EmergencyType.values
                            .map(
                              (v) => DropdownMenuItem(
                                value: v,
                                child: Text(v.label),
                              ),
                            )
                            .toList(),
                        onChanged: _busy
                            ? null
                            : (value) => setState(() => _category = value!),
                      ),
                      TextFormField(
                        controller: _people,
                        enabled: !_busy,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'จำนวนคนที่ต้องการความช่วยเหลือ',
                        ),
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          return n == null || n < 1 || n > 999
                              ? 'ระบุจำนวน 1–999 คน'
                              : null;
                        },
                      ),
                      TextFormField(
                        controller: _details,
                        enabled: !_busy,
                        maxLength: 1000,
                        minLines: 2,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'รายละเอียด / จุดสังเกต / สิ่งที่ต้องการ',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SelectableText(_location?.summary ?? 'ยังไม่ได้แนบพิกัด'),
                if (_location != null) LocationButton(location: _location!),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _run(() async {
                              setState(() => _readingLocation = true);
                              try {
                                final fix = await SosLocationService()
                                    .capture();
                                if (mounted) setState(() => _location = fix);
                              } finally {
                                if (mounted) {
                                  setState(() => _readingLocation = false);
                                }
                              }
                            }),
                      icon: const Icon(Icons.my_location),
                      label: const Text('อ่าน GPS'),
                    ),
                    if (_location != null)
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() => _location = null),
                        child: const Text('ไม่แนบพิกัด'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  active
                      ? 'ผู้รับเดิม (ยกเลิก SOS ก่อนเปลี่ยนผู้รับ)'
                      : 'ผู้รับข้อความ SOS เพิ่มเติม (ไม่จำเป็นต้องเลือก)',
                ),
                if (service.peers.isEmpty)
                  const Text(
                    'เปิด SOS ไว้ก่อนได้ สถานะจะประกาศเมื่อเชื่อมต่อเครื่องอื่น',
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
                FilledButton.icon(
                  onPressed: _busy || !service.ready ? null : _send,
                  icon: const Icon(Icons.sos),
                  label: Text(active ? 'อัปเดต SOS' : 'ตรวจข้อมูลและส่ง SOS'),
                ),
                if (active)
                  OutlinedButton(
                    onPressed: _busy ? null : () => _run(service.cancelSos),
                    child: const Text('ยกเลิก SOS และแจ้งผู้รับเดิม'),
                  ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
