import 'package:flutter/material.dart';

/// Isolated presentation state: never writes to MessageService or the database.
class DemoFeaturesScreen extends StatefulWidget {
  const DemoFeaturesScreen({super.key, this.media = false});
  final bool media;
  @override
  State<DemoFeaturesScreen> createState() => _DemoFeaturesScreenState();
}

class _DemoFeaturesScreenState extends State<DemoFeaturesScreen> {
  bool _online = false;
  bool _account = false;
  bool _syncing = false;
  bool _synced = false;
  bool _fail = false;
  String? _error;
  final List<String> _attachments = [];

  Future<void> _sync() async {
    setState(() {
      _syncing = true;
      _error = null;
      _synced = false;
    });
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() {
      _syncing = false;
      _synced = !_fail;
      _error = _fail
          ? 'จำลองข้อผิดพลาด • ปิดสวิตช์ข้อผิดพลาดแล้วลองใหม่'
          : null;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.media ? 'สื่อในแชต • จำลอง' : 'บัญชีและซิงก์ • จำลอง'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'โหมดจำลองเท่านั้น\nไม่มีการส่งสื่อ สมัครบัญชี หรืออัปโหลดข้อมูลจริง ข้อมูลตัวอย่างจะหายเมื่อออกจากหน้านี้',
            ),
          ),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('อินเทอร์เน็ตจำลอง'),
          value: _online,
          onChanged: _syncing
              ? null
              : (v) => setState(() {
                  _online = v;
                  _synced = false;
                }),
        ),
        if (widget.media) ...[
          const Text(
            'เลือกสื่อตัวอย่าง',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const Text(
            'แสดงขั้นตอนแนบสื่อด้วยตัวอย่าง ยังไม่เลือกไฟล์หรือเล่นวิดีโอจริง',
          ),
          Wrap(
            spacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed: () =>
                    setState(() => _attachments.add('รูปภาพตัวอย่าง')),
                icon: const Icon(Icons.image_outlined),
                label: const Text('แนบรูปตัวอย่าง'),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    setState(() => _attachments.add('วิดีโอตัวอย่าง')),
                icon: const Icon(Icons.videocam_outlined),
                label: const Text('แนบวิดีโอตัวอย่าง'),
              ),
            ],
          ),
          if (_attachments.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('ยังไม่มีสื่อแนบ'),
            ),
          for (var i = 0; i < _attachments.length; i++)
            Card(
              child: ListTile(
                leading: Icon(
                  _attachments[i].startsWith('รูป') ? Icons.image : Icons.movie,
                ),
                title: Text('${_attachments[i]} • จำลอง'),
                subtitle: Text(
                  _online
                      ? 'ส่งแล้ว (จำลองเท่านั้น)'
                      : 'ค้างส่ง (จำลองเท่านั้น)',
                ),
                trailing: IconButton(
                  tooltip: 'ลบสื่อตัวอย่าง',
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _attachments.removeAt(i)),
                ),
              ),
            ),
        ] else ...[
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(
              _account
                  ? 'บัญชีตัวอย่าง • จำลอง'
                  : 'Guest • ไม่ต้องสมัครเพื่อใช้ SOS',
            ),
            subtitle: const Text('ไม่มีการเก็บอีเมลหรือรหัสผ่าน'),
          ),
          FilledButton(
            onPressed: !_online || _syncing
                ? null
                : () => setState(() {
                    _account = !_account;
                    _synced = false;
                  }),
            child: Text(
              _account ? 'ออกจากบัญชีจำลอง' : 'ทดลองเข้าสู่ระบบ / สมัครบัญชี',
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'กลับมาออนไลน์เพื่อซิงก์',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Text(
            !_online
                ? 'ออฟไลน์จำลอง • รอการเชื่อมต่อ'
                : !_account
                ? 'ออนไลน์จำลอง • เข้าบัญชีตัวอย่างก่อนซิงก์'
                : 'พร้อมทดลองซิงก์ข้อมูลตัวอย่าง 3 รายการ',
          ),
          SwitchListTile(
            title: const Text('จำลองข้อผิดพลาดในการซิงก์'),
            value: _fail,
            onChanged: _syncing ? null : (v) => setState(() => _fail = v),
          ),
          if (_syncing) const LinearProgressIndicator(),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (_synced)
            const Text(
              'ซิงก์ตัวอย่างครบ 3 รายการ • จำลอง ไม่มีข้อมูลถูกอัปโหลด',
            ),
          OutlinedButton.icon(
            onPressed: !_online || !_account || _syncing ? null : _sync,
            icon: const Icon(Icons.sync),
            label: const Text('ซิงก์ตัวอย่าง / ลองใหม่'),
          ),
        ],
      ],
    ),
  );
}
