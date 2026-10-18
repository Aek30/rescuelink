import '../services/app_preferences.dart';
import '../theme/rescue_theme.dart';

import 'package:flutter/material.dart';

import '../models/message_model.dart';

import 'dart:convert';

import '../models/sos_alert.dart';
import '../services/message_service.dart';
import '../services/sos_location_service.dart';
import '../widgets/location_button.dart';
import '../widgets/sos_confirmation_dialog.dart';
import '../services/sos_store.dart';
import 'my_sos_screen.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key, required this.service, this.mainTab = false});
  final MessageService service;
  final bool mainTab;
  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  String t(String key) => AppPreferences.instance.text(key);
  final _form = GlobalKey<FormState>();
  final _details = TextEditingController();
  final _people = TextEditingController(text: '1');
  EmergencyType _category = EmergencyType.medical;
  String? _specificCategory;
  SosLocation? _location;
  bool _locationRemoved = false;
  bool _usingCachedLocation = false;
  late final SosLocationService _locationService;
  final _recipients = <String>{};
  bool _busy = false;
  bool _editing = false;
  bool _readingLocation = false;
  String? _error;

  static const _ink = Color(0xFF102D43);
  Color get _muted => RescueTheme.mutedFor(context);
  Color get _orange => RescueTheme.accentFor(context);
  String get _requesterName {
    final existing = widget.service.mySos;
    if (existing != null) return existing.name;
    final displayName = AppPreferences.instance.displayName?.trim();
    return displayName != null && displayName.isNotEmpty
        ? displayName
        : widget.service.nearbyService.deviceName;
  }

  @override
  void initState() {
    super.initState();
    _locationService = SosLocationService(database: widget.service.database);

    final alert = widget.service.mySos;
    if (alert != null) {
      _details.text = alert.details;
      for (final label in ['น้ำท่วม', 'ไฟไหม้', 'อุบัติเหตุ']) {
        if (alert.details.startsWith('[$label] ')) {
          _specificCategory = label;
          _details.text = alert.details.substring(label.length + 3);
        }
      }
      _people.text = '${alert.people}';
      _category = alert.category;
      _location = alert.location;
      _recipients.addAll(widget.service.sosRecipients);
    }
  }

  @override
  void dispose() {
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
    if (_location == null && !_locationRemoved) {
      final saved = await _locationService.lastKnown();
      if (!mounted) return;
      if (saved != null) {
        setState(() {
          _location = saved;
          _usingCachedLocation = true;
        });
      }
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => SosConfirmationDialog(
        name: _requesterName,
        people: _people.text.trim(),
        category: t(_specificCategory ?? _category.label),
        details: _details.text,
        location: _location == null
            ? t('ส่งโดยไม่แนบพิกัด')
            : '${_usingCachedLocation ? 'พิกัดล่าสุดที่บันทึกไว้ (ไม่ใช่การอ่าน GPS ใหม่)\n' : ''}${_location!.summary}',
        recipients: _recipients
            .map((id) => widget.service.peers[id] ?? id)
            .toList(),
        translate: t,
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(
      () => widget.service.publishSos(
        name: _requesterName,
        people: int.parse(_people.text),
        category: _category,
        details: _specificCategory == null
            ? _details.text
            : '[${_specificCategory!}] ${_details.text}',
        recipients: Set.of(_recipients),
        location: _location,
      ),
    );
  }

  Future<void> _cancel() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(t("ยืนยันยกเลิกเหตุ — เลือกเหตุผล")),
        children: [
          for (final reason in [
            'ได้รับความช่วยเหลือแล้ว',
            'ปลอดภัยแล้ว',
            'แจ้งผิด',
            'อื่น ๆ',
          ])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, reason),
              child: Text(t(reason)),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context),
            child: Text(t("กลับ")),
          ),
        ],
      ),
    );
    if (reason == null || !mounted) return;
    await _run(() async {
      final alert = widget.service.mySos;
      if (alert == null) return;
      await widget.service.database.setSetting(
        'sosCancellation:${alert.incidentId}',
        jsonEncode({
          'reason': reason,
          'at': DateTime.now().toUtc().toIso8601String(),
        }),
      );
      await widget.service.publishSos(
        name: alert.name,
        people: alert.people,
        category: alert.category,
        details: '[ยกเลิก: $reason] ${alert.details}'.substring(
          0,
          ('[ยกเลิก: $reason] ${alert.details}').length.clamp(0, 1000),
        ),
        recipients: widget.service.sosRecipients,
        location: alert.location,
        active: false,
      );
    });
  }

  InputDecoration _input(String label, {String? hint, IconData? icon}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon, size: 20, color: _muted),
      filled: true,
      fillColor: isDark ? const Color(0xFF161C24) : const Color(0xFFFCF8F1),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
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
        borderSide: BorderSide(color: _orange, width: 1.5),
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
                  style: TextStyle(color: _orange, fontWeight: FontWeight.w800),
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
            style: TextStyle(color: _muted, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

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
          for (final choice in <(EmergencyType, String, IconData)>[
            (EmergencyType.other, 'น้ำท่วม', Icons.flood_outlined),
            (
              EmergencyType.other,
              'ไฟไหม้',
              Icons.local_fire_department_outlined,
            ),
            (EmergencyType.other, 'อุบัติเหตุ', Icons.car_crash_outlined),
            (
              EmergencyType.medical,
              'เจ็บป่วย / การแพทย์',
              Icons.medical_services_outlined,
            ),
            (
              EmergencyType.trapped,
              'ติดอยู่ในพื้นที่อันตราย',
              Icons.person_pin_circle_outlined,
            ),
            (EmergencyType.other, 'อื่น ๆ', Icons.sos),
            (
              EmergencyType.supplies,
              'ต้องการอาหาร / น้ำ',
              Icons.water_drop_outlined,
            ),
          ])
            SizedBox(
              width: width,
              child: Semantics(
                selected:
                    _category == choice.$1 &&
                    (_specificCategory ??
                            (_category == EmergencyType.other
                                ? 'อื่น ๆ'
                                : choice.$2)) ==
                        choice.$2,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.all(14),
                    foregroundColor:
                        _category == choice.$1 &&
                            (_specificCategory ??
                                    (_category == EmergencyType.other
                                        ? 'อื่น ๆ'
                                        : choice.$2)) ==
                                choice.$2
                        ? _orange
                        : (isDark ? const Color(0xFFF1F5F9) : _ink),
                    backgroundColor:
                        _category == choice.$1 &&
                            (_specificCategory ??
                                    (_category == EmergencyType.other
                                        ? 'อื่น ๆ'
                                        : choice.$2)) ==
                                choice.$2
                        ? (isDark
                              ? const Color(0xFF3D2314)
                              : const Color(0xFFFFEADB))
                        : (isDark ? const Color(0xFF161C24) : Colors.white),
                    side: BorderSide(
                      color:
                          _category == choice.$1 &&
                              (_specificCategory ??
                                      (_category == EmergencyType.other
                                          ? 'อื่น ๆ'
                                          : choice.$2)) ==
                                  choice.$2
                          ? _orange
                          : (isDark
                                ? const Color(0xFF283442)
                                : const Color(0xFFEAE2D8)),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                          _category = choice.$1;
                          _specificCategory =
                              choice.$1 == EmergencyType.other &&
                                  choice.$2 != 'อื่น ๆ'
                              ? choice.$2
                              : null;
                        }),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(choice.$3, size: 25),
                      const SizedBox(height: 10),
                      Text(
                        t(choice.$2),
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
      final result = await _locationService.captureWithFallback();
      if (mounted) {
        setState(() {
          _location = result.location;
          _usingCachedLocation = result.cached;
          _locationRemoved = false;
        });
      }
    } finally {
      if (mounted) setState(() => _readingLocation = false);
    }
  });

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.service, AppPreferences.instance]),
    builder: (context, _) {
      final service = widget.service;
      final current = service.mySos;
      final active = current?.isActiveAt(DateTime.now().toUtc()) == true;
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
        backgroundColor: isDark
            ? const Color(0xFF0C1017)
            : const Color(0xFFFCF8F1),
        appBar: AppBar(
          automaticallyImplyLeading: !widget.mainTab,
          actions: [
            IconButton(
              tooltip: t("รายการเหตุ SOS ของฉัน"),
              icon: const Icon(Icons.history),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => MySosScreen(
                    store: SosStore(service.database),
                    onCreate: () => Navigator.pop(context),
                  ),
                ),
              ),
            ),
          ],
          backgroundColor: isDark
              ? const Color(0xFF0C1017)
              : const Color(0xFFFCF8F1),
          surfaceTintColor: Colors.transparent,
          foregroundColor: inkColor,
          title: Text(
            t("SOS — ขอความช่วยเหลือฉุกเฉิน"),
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
                    if (_busy) LinearProgressIndicator(color: _orange),
                    if (_error != null || service.error != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF381815)
                              : const Color(0xFFFFE8E4),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          _error ?? service.error!,
                          style: TextStyle(
                            color: isDark
                                ? const Color(0xFFFF897D)
                                : const Color(0xFF9B3021),
                          ),
                        ),
                      ),
                    ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark
                                ? const [Color(0xFF2C1E17), Color(0xFF1E1714)]
                                : const [Color(0xFFFFE9DC), Color(0xFFFFF5EC)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: isDark
                              ? Border.all(color: const Color(0xFF4A2B20))
                              : null,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF3D251A)
                                    : Colors.white.withValues(alpha: .8),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                Icons.sos_rounded,
                                color: _orange,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    active
                                        ? t("SOS ของคุณเปิดอยู่")
                                        : t("ให้คนใกล้ตัวช่วยคุณ"),
                                    style: TextStyle(
                                      color: inkColor,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      height: 1.25,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    t("ระบุเหตุ จำนวนคน และตำแหน่งของคุณ"),
                                    style: TextStyle(
                                      color: isDark
                                          ? const Color(0xFFC4B5A5)
                                          : const Color(0xFF805E4F),
                                      fontSize: 12,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (current != null)
                        _section(
                          '✓',
                          active
                              ? t("บันทึกคำขอแล้ว")
                              : t("บันทึกการยกเลิกแล้ว"),
                          t("ยังไม่ใช่การตอบรับจากเจ้าหน้าที่"),
                          [
                            Text(
                              '${current.category.label} • ${current.updatedAt.toLocal()}',
                            ),
                            Text(current.details),
                            if (deliveries.isEmpty)
                              Text(
                                t(
                                  "บันทึกในเครื่อง • รอประกาศผ่าน P2P ยังไม่มีการยืนยันจากผู้รับ",
                                ),
                              ),
                            for (final m in deliveries)
                              Text(
                                '${service.peers[m.receiverId] ?? m.receiverId}: ${switch (m.status) {
                                  MessageStatus.pending => t("รอเชื่อมต่อเพื่อส่ง"),
                                  MessageStatus.sent => t("ส่งแล้ว รอเครื่องปลายทางยืนยัน"),
                                  MessageStatus.delivered => t("เครื่องปลายทางบันทึกแล้ว"),
                                  MessageStatus.synced => t("ข้อมูลเก่าระบุซิงก์แล้ว • ไม่ยืนยันการรับ"),
                                }}',
                              ),
                          ],
                        ),
                      if (active)
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() => _editing = !_editing),
                          child: Text(t("เพิ่มข้อมูล / อัปเดต SOS")),
                        ),
                      if (!active || _editing) ...[
                        Form(
                          key: _form,
                          child: Column(
                            children: [
                              _section(
                                '01',
                                t("เกิดอะไรขึ้น?"),
                                t("เลือกประเภทเหตุที่ใกล้เคียงที่สุด"),
                                [
                                  _categoryPicker(),
                                  const SizedBox(height: 18),
                                  TextFormField(
                                    controller: _details,
                                    enabled: !_busy,
                                    maxLength: _specificCategory == null
                                        ? 1000
                                        : 970,
                                    minLines: 3,
                                    maxLines: 5,
                                    decoration: _input(
                                      t("รายละเอียดเพิ่มเติม"),
                                      hint: t(
                                        "เช่น ติดอยู่ชั้น 2 ต้องการน้ำดื่ม",
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              _section(
                                '02',
                                t("จำนวนผู้ต้องการความช่วยเหลือ"),
                                t("นับรวมตัวคุณและผู้ที่อยู่ด้วย"),
                                [
                                  TextFormField(
                                    controller: _people,
                                    enabled: !_busy,
                                    keyboardType: TextInputType.number,
                                    decoration: _input(
                                      t("จำนวนคนที่ต้องการความช่วยเหลือ"),
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
                          t("คุณอยู่ที่ไหน?"),
                          t("แนบพิกัดเพื่อให้ค้นหาคุณได้ง่ายขึ้น"),
                          [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF14221E)
                                    : const Color(0xFFF2F6F5),
                                borderRadius: BorderRadius.circular(16),
                                border: isDark
                                    ? Border.all(color: const Color(0xFF1F3830))
                                    : null,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.location_on_outlined,
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? const Color(0xFF8CDAC1)
                                        : const Color(0xFF38776B),
                                    size: 28,
                                  ),
                                  const SizedBox(height: 10),
                                  SelectableText(
                                    _location == null
                                        ? 'ยังไม่ได้แนบพิกัด'
                                        : '${_usingCachedLocation ? 'อ่าน GPS ใหม่ไม่ได้หรือใช้ข้อมูลที่บันทึกไว้\nพิกัดล่าสุด (ตรวจวันเวลาก่อนส่ง)\n' : ''}${_location!.summary}',
                                  ),
                                  if (_location == null)
                                    Text(
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
                              Padding(
                                padding: EdgeInsets.only(top: 12),
                                child: Text(
                                  t(
                                    "กำลังอ่านตำแหน่ง สูงสุด 60 วินาที กรุณาอยู่บริเวณโล่งและเปิดหน้านี้ค้างไว้",
                                  ),
                                ),
                              ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _busy ? null : _readLocation,
                                icon: const Icon(Icons.my_location),
                                label: Text(t("ใช้ตำแหน่งปัจจุบัน")),
                              ),
                            ),
                            if (_location != null) ...[
                              LocationButton(location: _location!),
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => setState(() {
                                        _location = null;
                                        _locationRemoved = true;
                                        _usingCachedLocation = false;
                                      }),
                                child: Text(t("ไม่แนบพิกัด")),
                              ),
                            ],
                          ],
                        ),
                        Material(
                          color: isDark
                              ? const Color(0xFF161C24)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          clipBehavior: Clip.antiAlias,
                          child: ExpansionTile(
                            shape: const Border(),
                            collapsedShape: const Border(),
                            leading: Icon(
                              Icons.group_add_outlined,
                              color: _muted,
                            ),
                            title: Text(
                              t("ผู้รับเพิ่มเติม"),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              active
                                  ? t("ยกเลิก SOS ก่อนเปลี่ยนผู้รับ")
                                  : t("ไม่จำเป็นต้องเลือก"),
                              style: TextStyle(fontSize: 12, color: _muted),
                            ),
                            children: [
                              if (service.peers.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    t("คำขอจะประกาศเมื่อเชื่อมต่อเครื่องอื่น"),
                                  ),
                                ),
                              for (final peer in service.peers.entries)
                                CheckboxListTile(
                                  title: Text(peer.value),
                                  subtitle: Text(
                                    service.connectionLabel(peer.key),
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
                              backgroundColor: Color(0xFFFF4D4D),
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
                              active
                                  ? t("เพิ่มข้อมูล / อัปเดต SOS")
                                  : t("ส่งสัญญาณ SOS"),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: Text(
                            t("คุณจะได้ตรวจสอบข้อมูลอีกครั้งก่อนส่ง"),
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: _muted),
                          ),
                        ),
                      ],
                      if (active)
                        OutlinedButton(
                          onPressed: _busy ? null : () => _run(service.retry),
                          child: Text(t("ส่งซ้ำ (เหตุเดิม)")),
                        ),
                      if (active)
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: Theme.of(context)
                                .colorScheme
                                .error,
                          ),
                          onPressed: _busy ? null : _cancel,
                          child: Text(t("ยกเลิก SOS และแจ้งผู้รับเดิม")),
                        ),
                    ],
                    const SizedBox(height: 18),
                    ExpansionTile(
                      shape: Border(),
                      collapsedShape: Border(),
                      title: Text(
                        t("การส่ง SOS ทำงานอย่างไร?"),
                        style: TextStyle(fontSize: 12, color: _muted),
                      ),
                      children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Text(
                            AppPreferences.instance.t(
                              'ใช้ P2P โดยไม่ต้องมีอินเทอร์เน็ต คำขอที่บันทึกจะประกาศเมื่อเชื่อมต่อเครื่องอื่น การรับข้อความไม่ใช่การยืนยันรับเคส',
                              'P2P works without internet. Saved requests broadcast when devices connect. Message receipt does not confirm case assignment.',
                            ),
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
}
