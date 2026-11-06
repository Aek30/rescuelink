import 'dart:convert';

const sosEmergencyLabels = {
  'full_name': 'ชื่อ-นามสกุล',
  'phone': 'หมายเลขโทรศัพท์',
  'date_of_birth': 'วันเดือนปีเกิด',
  'medical_conditions': 'โรคประจำตัว',
  'allergies': 'ประวัติแพ้ยา / แพ้อาหาร',
  'medications': 'ยาที่ใช้อยู่',
  'medical_notes': 'ข้อมูลสุขภาพเพิ่มเติม',
  'blood_group': 'กรุ๊ปเลือด (ข้อมูลที่แจ้งเอง)',
  'emergency_contact': 'ผู้ติดต่อฉุกเฉิน',
};

const sosEmergencyGroups = {
  'ข้อมูลส่วนตัว': ['full_name', 'phone', 'date_of_birth'],
  'ข้อมูลสุขภาพ': [
    'medical_conditions',
    'allergies',
    'medications',
    'medical_notes',
    'blood_group',
  ],
  'ผู้ติดต่อฉุกเฉิน': ['emergency_contact'],
};

Map<String, String> sosEmergencyOptions(Map<String, dynamic> profile) {
  String value(String key) => (profile[key] as String? ?? '').trim();
  final result = <String, String>{};
  for (final key in ['full_name', 'phone']) {
    if (value(key).isNotEmpty) result[key] = value(key);
  }
  final dob = DateTime.tryParse(value('date_of_birth'));
  if (dob != null) {
    result['date_of_birth'] = '${dob.day}/${dob.month}/${dob.year + 543}';
  }
  if (profile['health_consent'] != true) return result;
  for (final key in [
    'medical_conditions',
    'allergies',
    'medications',
    'medical_notes',
  ]) {
    if (value(key).isNotEmpty) result[key] = value(key);
  }
  final blood = value('blood_group');
  if (blood.isNotEmpty && blood != 'ไม่ทราบ') {
    final rh = value('rh_factor');
    result['blood_group'] =
        '$blood${rh.isNotEmpty && rh != 'ไม่ทราบ' ? ' $rh' : ''}';
  }
  final contact = [
    value('emergency_contact_name'),
    value('emergency_contact_phone'),
    value('emergency_contact_relation'),
  ].where((part) => part.isNotEmpty).join(' • ');
  if (contact.isNotEmpty) result['emergency_contact'] = contact;
  return result;
}

bool validSosEmergencyInfo(Map<String, String> info) =>
    info.entries.every(
      (entry) =>
          sosEmergencyLabels.containsKey(entry.key) &&
          entry.value.trim().isNotEmpty &&
          entry.value.length <= 2000,
    ) &&
    utf8.encode(jsonEncode(info)).length <= 8000;

String sosEmergencyInfoText(Map<String, String> info) => sosEmergencyLabels
    .entries
    .where((entry) => info.containsKey(entry.key))
    .map((entry) => '${entry.value}: ${info[entry.key]}')
    .join('\n');
