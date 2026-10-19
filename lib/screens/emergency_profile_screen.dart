import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/emergency_profile_service.dart';
import '../services/emergency_profile_store.dart';
import '../widgets/privacy_notice.dart';

// โทนสีเดิมของ RescueLink: ส้ม / กรมท่า / ครีม
const _orange = Color(0xFFF28C28);
const _navy = Color(0xFF1B2A49);
const _line = Color(0xFFEADFCB);

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
  bool messageIsError = false;
  bool messageIsSuccess = false;
  String? message;
  IconData messageIcon = Icons.info_outline;

  static const labels = {
    'full_name': 'ชื่อ-นามสกุล',
    'display_name': 'ชื่อที่แสดง',
    'phone': 'หมายเลขโทรศัพท์',
    'medical_conditions': 'โรคประจำตัว',
    'allergies': 'ประวัติการแพ้ยา อาหาร หรือสารอื่น ๆ',
    'medications': 'ยาที่ใช้เป็นประจำ',
    'medical_notes': 'ข้อมูลสุขภาพเพิ่มเติม',
    'emergency_contact_name': 'ชื่อ-นามสกุลผู้ติดต่อ',
    'emergency_contact_phone': 'หมายเลขโทรศัพท์ผู้ติดต่อ',
    'emergency_contact_relation': 'ความสัมพันธ์กับคุณ',
  };

  static const _hints = {
    'full_name': 'ชื่อและนามสกุล',
    'display_name': 'เช่น ชื่อเล่น',
    'phone': 'เช่น 0812345678',
    'medical_conditions': 'เช่น เบาหวาน หรือไม่มี',
    'allergies': 'สิ่งที่แพ้และอาการ หรือไม่ทราบ',
    'medications': 'ชื่อยา ขนาด และความถี่',
    'medical_notes': 'ข้อควรระวังเพิ่มเติม',
    'emergency_contact_name': 'ชื่อและนามสกุล',
    'emergency_contact_phone': 'เช่น 0812345678',
    'emergency_contact_relation': 'เช่น มารดา หรือเพื่อน',
  };

  static const _icons = {
    'full_name': Icons.badge_outlined,
    'display_name': Icons.person_outline,
    'phone': Icons.phone_outlined,
    'medical_conditions': Icons.monitor_heart_outlined,
    'allergies': Icons.warning_amber_rounded,
    'medications': Icons.medication_outlined,
    'medical_notes': Icons.notes_rounded,
    'emergency_contact_name': Icons.contact_emergency_outlined,
    'emergency_contact_phone': Icons.phone_in_talk_outlined,
    'emergency_contact_relation': Icons.family_restroom_outlined,
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

  void _setMessage(
    String? text, {
    bool error = false,
    bool success = false,
    IconData? icon,
  }) {
    message = text;
    messageIsError = error;
    messageIsSuccess = success;
    messageIcon =
        icon ??
        (error
            ? Icons.error_outline
            : success
            ? Icons.check_circle_outline_rounded
            : Icons.info_outline);
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
      if (result.pending) {
        _setMessage(
          'บันทึกในเครื่องแล้ว · รอซิงก์',
          icon: Icons.schedule_rounded,
        );
      } else if (result.offline) {
        _setMessage('กำลังใช้ข้อมูลออฟไลน์', icon: Icons.cloud_off_rounded);
      } else {
        _setMessage('ซิงก์แล้ว', success: true, icon: Icons.cloud_done_rounded);
      }
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      _setMessage(null);
    });
    try {
      await action();
    } catch (e) {
      if (mounted) {
        setState(
          () => _setMessage(
            e is StateError
                ? e.message.toString()
                : 'บันทึกไม่สำเร็จ กรุณาลองใหม่',
            error: true,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _save() async {
    if (!form.currentState!.validate()) return;
    if (!terms) {
      setState(
        () => _setMessage(
          'กรุณายอมรับข้อกำหนดและนโยบายความเป็นส่วนตัว',
          error: true,
        ),
      );
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
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
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
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

  // ---------- UI helpers ----------

  InputDecoration _decoration(
    String label, {
    IconData? icon,
    String? counter,
    String? hint,
  }) => InputDecoration(
    labelText: label,
    hintText: hint,
    hintMaxLines: 2,
    errorMaxLines: 3,
    counterText: counter,
    prefixIcon: icon == null ? null : Icon(icon, size: 20),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _line),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: _line.withValues(alpha: .5)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _orange, width: 2),
    ),
  );

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
          maxLines: healthFields[key] == 2000 ? 3 : 1,
          keyboardType: key.contains('phone')
              ? TextInputType.phone
              : TextInputType.text,
          decoration: _decoration(
            '${labels[key]}${required ? ' *' : ''}',
            icon: _icons[key],
            hint: _hints[key],
            counter: '',
          ),
          validator: required
              ? (v) => v == null || v.trim().isEmpty
                    ? 'กรุณากรอก${labels[key]}'
                    : null
              : null,
        ),
      );

  Widget _section({
    required IconData icon,
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: Colors.white.withValues(alpha: .65),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: _line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _orange.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: _orange, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _navy,
                    ),
                  ),
                ),
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: _navy.withValues(alpha: .65),
                ),
              ),
            ],
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    ),
  );

  Widget _statusBanner() {
    final color = messageIsError
        ? Colors.redAccent
        : messageIsSuccess
        ? const Color(0xFF16A34A)
        : _navy;
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      child: message == null
          ? const SizedBox(width: double.infinity)
          : Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withValues(alpha: .25)),
              ),
              child: Row(
                children: [
                  Icon(messageIcon, size: 20, color: color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      message!,
                      style: TextStyle(fontSize: 13, color: color),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _dobTile() => InkWell(
    borderRadius: BorderRadius.circular(14),
    onTap: busy
        ? null
        : () async {
            final value = await showDatePicker(
              context: context,
              initialDate: dob ?? DateTime(2000),
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
            );
            if (value != null && mounted) setState(() => dob = value);
          },
    child: Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          const Icon(Icons.cake_outlined, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'วันเดือนปีเกิด (ถ้าทราบ)',
                  style: TextStyle(
                    fontSize: 12,
                    color: _navy.withValues(alpha: .6),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dob == null
                      ? 'ไม่ได้ระบุ'
                      : '${dob!.day}/${dob!.month}/${dob!.year}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _navy,
                  ),
                ),
              ],
            ),
          ),
          if (dob != null)
            IconButton(
              tooltip: 'ล้างวันเกิด',
              onPressed: busy ? null : () => setState(() => dob = null),
              icon: const Icon(Icons.clear),
            ),
        ],
      ),
    ),
  );

  Widget _dropdown({
    required String label,
    required String value,
    required Iterable<String> items,
    required ValueChanged<String> onChanged,
    required Key fieldKey,
  }) => DropdownButtonFormField<String>(
    key: fieldKey,
    initialValue: value,
    isExpanded: true,
    decoration: _decoration(label),
    items: items
        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
        .toList(),
    onChanged: busy || !consent ? null : (v) => onChanged(v!),
  );

  Widget _header() => Container(
    padding: const EdgeInsets.all(16),
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [_navy, Color(0xFF2E4372)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(22),
    ),
    child: Row(
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: _orange,
          child: const Icon(Icons.favorite_rounded, color: Colors.white),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: fields['display_name']!,
                builder: (_, v, _) => Text(
                  v.text.trim().isEmpty
                      ? 'โปรไฟล์ฉุกเฉินของฉัน'
                      : v.text.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'ข้อมูลสุขภาพไม่ส่งผ่าน Nearby อัตโนมัติ',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .75),
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  // ---------- build ----------

  @override
  Widget build(BuildContext context) {
    final emergencyKeys = healthFields.keys
        .where((k) => k.startsWith('emergency_contact'))
        .toList();
    final medicalKeys = healthFields.keys.where(
      (k) => !k.startsWith('emergency_contact'),
    );

    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        foregroundColor: _navy,
        elevation: 0,
        title: const Text(
          'ข้อมูลส่วนตัวและสุขภาพ',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'ซิงก์ข้อมูล',
            onPressed: busy
                ? null
                : () => _run(() async => _apply(await repository.read())),
            icon: const Icon(Icons.sync_rounded),
          ),
        ],
        bottom: busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(
                  minHeight: 3,
                  color: _orange,
                  backgroundColor: Colors.transparent,
                ),
              )
            : null,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Form(
            key: form,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(),
                  _statusBanner(),

                  // 1) ข้อมูลทั่วไป
                  _section(
                    icon: Icons.person_rounded,
                    title: 'ข้อมูลส่วนตัว',
                    subtitle: '* จำเป็นต้องกรอก',
                    children: [
                      _field('full_name', required: true),
                      _field('display_name', required: true),
                      _field('phone'),
                      _dobTile(),
                    ],
                  ),

                  // 2) ข้อมูลสุขภาพ
                  _section(
                    icon: Icons.health_and_safety_rounded,
                    title: 'ข้อมูลสุขภาพ',
                    subtitle:
                        'กรอกได้ตามสมัครใจ ยังไม่แชร์ให้ผู้ช่วยเหลือ '
                        'ปิดความยินยอมแล้วบันทึกเพื่อลบข้อมูลสุขภาพ',
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Material(
                          color: consent
                              ? _orange.withValues(alpha: .12)
                              : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(color: consent ? _orange : _line),
                          ),
                          child: SwitchListTile(
                            activeThumbColor: _orange,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                            ),
                            value: consent,
                            onChanged: busy
                                ? null
                                : (v) => setState(() => consent = v),
                            title: const Text(
                              'ยินยอมจัดเก็บและใช้ข้อมูลสุขภาพฉุกเฉิน',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _navy,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (!consent)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Icon(
                                Icons.lock_outline,
                                size: 16,
                                color: _navy.withValues(alpha: .5),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'เปิดความยินยอมเพื่อกรอกข้อมูลสุขภาพ',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: _navy.withValues(alpha: .55),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: _dropdown(
                              fieldKey: ValueKey('blood-$blood'),
                              label: 'กรุ๊ปเลือด',
                              value: blood,
                              items: bloodGroups,
                              onChanged: (v) => setState(() => blood = v),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: _dropdown(
                              fieldKey: ValueKey('rh-$rh'),
                              label: 'หมู่เลือด Rh',
                              value: rh,
                              items: rhFactors,
                              onChanged: (v) => setState(() => rh = v),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(2, 8, 2, 12),
                        child: Text(
                          'กรุ๊ปเลือดที่กรอกเองใช้ให้เลือดไม่ได้โดยไม่มีการตรวจยืนยันทางการแพทย์',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ),
                      for (final key in medicalKeys) _field(key, health: true),
                    ],
                  ),

                  // 3) ผู้ติดต่อฉุกเฉิน
                  _section(
                    icon: Icons.contact_phone_rounded,
                    title: 'ผู้ติดต่อฉุกเฉิน',
                    subtitle: 'ไม่จำเป็นต้องกรอก',
                    children: [
                      for (final key in emergencyKeys)
                        _field(key, health: true),
                    ],
                  ),

                  // 4) ข้อกำหนด + ลบข้อมูล
                  _section(
                    icon: Icons.privacy_tip_rounded,
                    title: 'ความเป็นส่วนตัว',
                    children: [
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: _orange,
                        value: terms,
                        onChanged: busy
                            ? null
                            : (v) => setState(() => terms = v!),
                        title: const Text(
                          'ยอมรับข้อกำหนดและนโยบายความเป็นส่วนตัว',
                          style: TextStyle(fontSize: 14, color: _navy),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => showPrivacyNotice(context),
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: const Text('อ่านนโยบายความเป็นส่วนตัว'),
                          style: TextButton.styleFrom(foregroundColor: _orange),
                        ),
                      ),
                      const Divider(height: 16, color: _line),
                      FilledButton.icon(
                        onPressed: busy ? null : _save,
                        icon: const Icon(Icons.save_rounded),
                        label: const Text('บันทึกข้อมูล'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _orange,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: busy || !loaded ? null : _delete,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('ถอนความยินยอมและลบข้อมูลสุขภาพ'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                          minimumSize: const Size.fromHeight(46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
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
  }
}
