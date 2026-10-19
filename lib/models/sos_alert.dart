import 'dart:convert';

enum EmergencyType {
  medical('เจ็บป่วย / บาดเจ็บ'),
  trapped('ติดอยู่ / ออกไม่ได้'),
  supplies('ต้องการอาหาร / น้ำ'),
  other('เหตุฉุกเฉินอื่น'),
  flood('น้ำท่วม'),
  fire('ไฟไหม้'),
  accident('อุบัติเหตุ');

  const EmergencyType(this.label);
  final String label;
  String get shortLabel => switch (this) {
    medical => 'เจ็บป่วย / บาดเจ็บ',
    trapped => 'ติดพื้นที่อันตราย',
    supplies => 'อาหาร / น้ำ',
    other => 'เหตุอื่น ๆ',
    _ => label,
  };
  // Older peers and the existing cloud constraint accept these four values.
  // The optional categories array carries the exact types for updated clients.
  EmergencyType get legacyCategory => switch (this) {
    flood || fire || accident => other,
    _ => this,
  };
}

class SosLocation {
  SosLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.capturedAt,
    this.manuallySelected = false,
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
  final bool manuallySelected;
  Map<String, Object> toMap() => {
    if (manuallySelected) 'manuallySelected': true,
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
    manuallySelected: map['manuallySelected'] == true,
  );
  String get summary {
    final local = capturedAt.toLocal();
    final clock =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    final quality = manuallySelected
        ? 'ปักหมุดเอง'
        : 'ความแม่นยำ ±${accuracy.toStringAsFixed(0)} ม.';
    return '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}\n'
        '$quality • ${local.day}/${local.month}/${local.year} $clock';
  }
}

// A revision is owned by the origin. Relaying never renews its expiry.
class SosAlert {
  SosAlert({
    required this.incidentId,
    required this.revision,
    required this.active,
    required this.name,
    required this.people,
    required EmergencyType category,
    List<EmergencyType>? categories,
    required this.details,
    required this.updatedAt,
    this.location,
  }) : categories = _normalize(categories ?? [category]) {
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
  final List<EmergencyType> categories;
  EmergencyType get category => categories.first;
  String get categoriesLabel => categories.map((e) => e.label).join(' • ');
  static List<EmergencyType> _normalize(List<EmergencyType> values) {
    final types = values.toSet();
    if (types.length > 1) types.remove(EmergencyType.other);
    if (types.isEmpty) throw const FormatException('Select an emergency type');
    return List.unmodifiable(types);
  }

  final DateTime updatedAt;
  final SosLocation? location;
  static const lifetime = Duration(hours: 24);
  DateTime get expiresAt => updatedAt.add(lifetime);
  bool isExpired(DateTime now) => active && !now.isBefore(expiresAt);
  bool isActiveAt(DateTime now) => active && !isExpired(now);
  String toJson() => jsonEncode({
    'version': 1,
    'incidentId': incidentId,
    'revision': revision,
    'active': active,
    'name': name,
    'people': people,
    'category': category.legacyCategory.name,
    // Preserve the original encoding for single legacy types: sync receipts
    // are keyed by the canonical JSON of previously stored alerts.
    if (categories.length > 1 || category != category.legacyCategory)
      'categories': categories.map((e) => e.name).toList(),
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
      categories: (map['categories'] as List?)
          ?.map((e) => EmergencyType.values.byName(e as String))
          .toList(),
      details: map['details'] as String,
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      location: map['location'] == null
          ? null
          : SosLocation.fromMap(map['location'] as Map<String, dynamic>),
    );
  }
  String get summary =>
      '${!active
          ? 'ยกเลิก SOS'
          : isExpired(DateTime.now().toUtc())
          ? 'SOS หมดอายุ'
          : 'SOS'} • $categoriesLabel'
      '\n$name • $people คน\n$details\n${location?.summary ?? 'ไม่ได้แนบพิกัด'}';
}
