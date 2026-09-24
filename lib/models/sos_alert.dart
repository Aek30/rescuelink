import 'dart:convert';

enum EmergencyType {
  medical('เจ็บป่วย / บาดเจ็บ'),
  trapped('ติดอยู่ / ออกไม่ได้'),
  supplies('ต้องการอาหาร / น้ำ'),
  other('เหตุฉุกเฉินอื่น');

  const EmergencyType(this.label);
  final String label;
}

class SosLocation {
  SosLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.capturedAt,
  }) {
    if (!latitude.isFinite ||
        latitude.abs() > 90 ||
        !longitude.isFinite ||
        longitude.abs() > 180 ||
        !accuracy.isFinite ||
        accuracy < 0) {
      throw const FormatException('Invalid coordinates');
    }
  }
  final double latitude, longitude, accuracy;
  final DateTime capturedAt;
  Map<String, Object> toMap() => {
    'latitude': latitude,
    'longitude': longitude,
    'accuracy': accuracy,
    'capturedAt': capturedAt.toUtc().toIso8601String(),
  };
  factory SosLocation.fromMap(Map<String, dynamic> map) => SosLocation(
    latitude: (map['latitude'] as num).toDouble(),
    longitude: (map['longitude'] as num).toDouble(),
    accuracy: (map['accuracy'] as num).toDouble(),
    capturedAt: DateTime.parse(map['capturedAt'] as String),
  );
  String get summary =>
      '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}'
      '\nความแม่นยำ ±${accuracy.toStringAsFixed(0)} ม. • ${capturedAt.toLocal()}';
}

// Incident ID + monotonically increasing revision prepare updates for future relay.
// Phase 3 only sends directly to connected, introduced peers.
class SosAlert {
  SosAlert({
    required this.incidentId,
    required this.revision,
    required this.active,
    required this.name,
    required this.people,
    required this.category,
    required this.details,
    required this.updatedAt,
    this.location,
  }) {
    if (incidentId.isEmpty ||
        incidentId.length > 128 ||
        revision < 1 ||
        name.trim().isEmpty ||
        name.length > 80 ||
        people < 1 ||
        people > 999 ||
        details.length > 1000) {
      throw const FormatException('Invalid SOS information');
    }
  }
  final String incidentId, name, details;
  final int revision, people;
  final bool active;
  final EmergencyType category;
  final DateTime updatedAt;
  final SosLocation? location;
  String toJson() => jsonEncode({
    'version': 1,
    'incidentId': incidentId,
    'revision': revision,
    'active': active,
    'name': name,
    'people': people,
    'category': category.name,
    'details': details,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'location': location?.toMap(),
  });
  factory SosAlert.fromJson(String source) {
    final map = jsonDecode(source) as Map<String, dynamic>;
    if (map['version'] != 1) {
      throw const FormatException('Unsupported SOS version');
    }
    return SosAlert(
      incidentId: map['incidentId'] as String,
      revision: map['revision'] as int,
      active: map['active'] as bool,
      name: map['name'] as String,
      people: map['people'] as int,
      category: EmergencyType.values.byName(map['category'] as String),
      details: map['details'] as String,
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      location: map['location'] == null
          ? null
          : SosLocation.fromMap(map['location'] as Map<String, dynamic>),
    );
  }
  String get summary =>
      '${active ? 'SOS' : 'ยกเลิก SOS'} • ${category.label}'
      '\n$name • $people คน\n$details\n${location?.summary ?? 'ไม่ได้แนบพิกัด'}';
}
