import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/emergency_profile_service.dart';
import '../services/emergency_profile_store.dart';
import '../widgets/privacy_notice.dart';

class EmergencyProfileScreen extends StatefulWidget {
  const EmergencyProfileScreen({super.key, this.repository});
  final EmergencyProfileRepository? repository;
  @override
  State<EmergencyProfileScreen> createState() => _EmergencyProfileScreenState();
}

class _EmergencyProfileScreenState extends State<EmergencyProfileScreen> {
  late final EmergencyProfileRepository repository;
  final form = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{
    for (final key in [
      'display_name',
      'full_name',
      'phone',
      ...healthFields.keys,
    ])
      key: TextEditingController(),
  };
  DateTime? dob;
  String blood = 'ไม่ทราบ', rh = 'ไม่ทราบ';
  bool consent = false, terms = false, busy = false, loaded = false;
  String? message;
  static const labels = {
    'full_name': 'ชื่อ-นามสกุล',
    'display_name': 'ชื่อที่แสดงใน RescueLink',
    'phone': 'เบอร์โทรศัพท์ (ถ้ามี)',
    'medical_conditions': 'โรคประจำตัวที่สำคัญ',
    'allergies': 'การแพ้ยา / อาหาร / สารอื่น',
    'medications': 'ยาที่ใช้เป็นประจำ',
    'medical_notes': 'ข้อควรระวังทางการแพทย์',
    'emergency_contact_name': 'ชื่อผู้ติดต่อฉุกเฉิน',
    'emergency_contact_phone': 'เบอร์โทรผู้ติดต่อฉุกเฉิน',
    'emergency_contact_relation': 'ความสัมพันธ์กับผู้ติดต่อฉุกเฉิน',
  };

  @override
  void initState() {
    super.initState();
    repository =
        widget.repository ??
        SupabaseEmergencyProfileRepository(AuthService.instance);
    _run(() async => _apply(await repository.read()));
  }

  @override
  void dispose() {
    for (final controller in fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _apply(EmergencyProfileResult result) {
    if (!mounted) return;
    setState(() {
      loaded = true;
      for (final entry in fields.entries) {
        entry.value.text = result.data[entry.key] as String? ?? '';
      }
      dob = DateTime.tryParse(result.data['date_of_birth'] as String? ?? '');
      blood = result.data['blood_group'] as String? ?? 'ไม่ทราบ';
      rh = result.data['rh_factor'] as String? ?? 'ไม่ทราบ';
      consent = result.data['health_consent'] == true;
      terms = result.data['terms_version'] == privacyVersion;
      message = result.pending
          ? 'บันทึกในพื้นที่ปลอดภัยของบัญชีนี้แล้ว รอซิงก์เมื่อเชื่อมต่อ Cloud ได้'
          : result.offline
          ? 'แสดงสำเนาออฟไลน์ของบัญชีนี้'
          : 'ข้อมูลซิงก์กับ Cloud แล้ว';
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) {
        setState(
          () => message = e is StateError
              ? e.message.toString()
              : 'บันทึกไม่สำเร็จ กรุณาลองใหม่',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _save() async {
    if (!form.currentState!.validate()) return;
    if (!terms) {
      setState(() => message = 'กรุณายอมรับข้อกำหนดและนโยบายความเป็นส่วนตัว');
      return;
    }
    await _run(() async {
      final data = <String, dynamic>{
        for (final entry in fields.entries) entry.key: entry.value.text.trim(),
        'date_of_birth': dob?.toIso8601String().substring(0, 10),
        'blood_group': blood,
        'rh_factor': rh,
        'health_consent': consent,
        'terms_version': privacyVersion,
      };
      _apply(await repository.save(data));
    });
  }

  Future<void> _delete() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ถอนความยินยอมและลบข้อมูลสุขภาพ'),
        content: const Text(
          'ข้อมูลสุขภาพและผู้ติดต่อฉุกเฉินจะถูกลบออกจากเครื่องทันที '
          'และจาก Cloud เมื่อซิงก์สำเร็จ บัญชีและประวัติข้อความยังคงอยู่',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ลบข้อมูลสุขภาพ'),
          ),
        ],
      ),
    );
    if (accepted == true && mounted) {
      await _run(() async => _apply(await repository.deleteHealth()));
    }
  }

  Widget _field(String key, {bool required = false, bool health = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          key: ValueKey('profile-$key'),
          controller: fields[key],
          enabled: !busy && (!health || consent),
          maxLength:
              healthFields[key] ??
              (key == 'phone'
                  ? 30
                  : key == 'full_name'
                  ? 200
                  : 100),
          maxLines: healthFields[key] == 2000 ? 2 : 1,
          keyboardType: key.contains('phone')
              ? TextInputType.phone
              : TextInputType.text,
          decoration: InputDecoration(
            labelText: '${labels[key]}${required ? ' *' : ''}',
            border: const OutlineInputBorder(),
          ),
          validator: required
              ? (v) => v == null || v.trim().isEmpty
                    ? 'กรุณากรอก${labels[key]}'
                    : null
              : null,
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('ข้อมูลส่วนตัวและสุขภาพ'),
      actions: [
        IconButton(
          tooltip: 'ซิงก์ข้อมูล',
          onPressed: busy
              ? null
              : () => _run(() async => _apply(await repository.read())),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (busy) const LinearProgressIndicator(),
              if (message != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(message!),
                ),
              _field('full_name', required: true),
              _field('display_name', required: true),
              _field('phone'),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('วันเดือนปีเกิด (ถ้าทราบ)'),
                subtitle: Text(
                  dob == null
                      ? 'ไม่ได้ระบุ'
                      : '${dob!.day}/${dob!.month}/${dob!.year}',
                ),
                trailing: IconButton(
                  tooltip: 'ล้างวันเกิด',
                  onPressed: busy ? null : () => setState(() => dob = null),
                  icon: const Icon(Icons.clear),
                ),
                onTap: busy
                    ? null
                    : () async {
                        final value = await showDatePicker(
                          context: context,
                          initialDate: dob ?? DateTime(2000),
                          firstDate: DateTime(1900),
                          lastDate: DateTime.now(),
                        );
                        if (value != null && mounted) {
                          setState(() => dob = value);
                        }
                      },
              ),
              const Divider(),
              const Text(
                'ข้อมูลสุขภาพและผู้ติดต่อฉุกเฉินเป็นทางเลือก ไม่ส่งให้อุปกรณ์ Nearby โดยอัตโนมัติ',
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: consent,
                onChanged: busy ? null : (v) => setState(() => consent = v!),
                title: const Text('ยินยอมจัดเก็บและใช้ข้อมูลสุขภาพฉุกเฉิน'),
                subtitle: const Text(
                  'เจ้าของบัญชีอ่านข้อมูลผ่านแอปได้ ระบบยังไม่แชร์ให้ผู้ช่วยเหลือ '
                  'เมื่อยกเลิกและบันทึก ข้อมูลสุขภาพจะถูกลบ',
                ),
              ),
              DropdownButtonFormField<String>(
                initialValue: blood,
                key: ValueKey('blood-$blood'),
                decoration: const InputDecoration(labelText: 'กรุ๊ปเลือด'),
                items: bloodGroups
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: busy || !consent
                    ? null
                    : (v) => setState(() => blood = v!),
              ),
              DropdownButtonFormField<String>(
                initialValue: rh,
                key: ValueKey('rh-$rh'),
                decoration: const InputDecoration(labelText: 'Rh'),
                items: rhFactors
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: busy || !consent
                    ? null
                    : (v) => setState(() => rh = v!),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'กรุ๊ปเลือดที่กรอกเองใช้ให้เลือดไม่ได้โดยไม่มีการตรวจยืนยันทางการแพทย์',
                ),
              ),
              for (final key in healthFields.keys) _field(key, health: true),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: terms,
                onChanged: busy ? null : (v) => setState(() => terms = v!),
                title: const Text('ยอมรับข้อกำหนดและนโยบายความเป็นส่วนตัว'),
              ),
              TextButton(
                onPressed: () => showPrivacyNotice(context),
                child: const Text('อ่านนโยบายความเป็นส่วนตัว'),
              ),
              FilledButton.icon(
                onPressed: busy ? null : _save,
                icon: const Icon(Icons.save),
                label: const Text('บันทึกข้อมูล'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: busy || !loaded ? null : _delete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('ถอนความยินยอมและลบสุขภาพ'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
