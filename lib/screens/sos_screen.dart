import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/message_model.dart';
import '../models/sos_alert.dart';
import '../services/app_preferences.dart';
import '../services/message_service.dart';
import '../services/sos_location_service.dart';
import '../services/sos_store.dart';
import '../theme/rescue_theme.dart';
import '../widgets/emergency_type_chip.dart';
import '../widgets/sos_confirmation_dialog.dart';
import '../widgets/sos_location_card.dart';
import '../widgets/sos_status_card.dart';
import '../widgets/sos_cancel_dialog.dart';
import 'my_sos_screen.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key, required this.service, this.mainTab = false});
  final MessageService service;
  final bool mainTab;
  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  final _details = TextEditingController();
  final _detailsFocus = FocusNode();
  final _types = <EmergencyType>{};
  final _recipients = <String>{};
  int _people = 1;
  bool _busy = false, _editing = false, _readingLocation = false;
  bool _locationRemoved = false;
  int _locationGeneration = 0;
  SosLocation? _location;
  Future<SosLocation?>? _locationRead;
  String? _error, _locationError;
  late final SosLocationService _locationService;
  Timer? _ageTimer;
  Timer? _expiryTimer;
  String? _activeIncidentId;

  String get _requesterName {
    final name =
        (widget.service.mySos?.isActiveAt(DateTime.now().toUtc()) == true
            ? widget.service.mySos?.name
            : null) ??
        AppPreferences.instance.displayName?.trim();
    return name != null && name.isNotEmpty
        ? name
        : widget.service.nearbyService.deviceName;
  }

  @override
  void initState() {
    super.initState();
    _locationService = SosLocationService(database: widget.service.database);
    final alert = widget.service.mySos;
    if (alert != null && alert.isActiveAt(DateTime.now().toUtc())) {
      _activeIncidentId = alert.incidentId;
      _details.text = alert.details;
      _types
        ..clear()
        ..addAll(alert.categories);
      _people = alert.people;
      _location = alert.location;
      _recipients.addAll(widget.service.sosRecipients);
    }
    _detailsFocus.addListener(_rebuild);
    widget.service.addListener(_syncIncident);
    _scheduleExpiry();
    _ageTimer = Timer.periodic(const Duration(minutes: 1), (_) => _rebuild());
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeLocation());
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _scheduleExpiry() {
    _expiryTimer?.cancel();
    final alert = widget.service.mySos;
    final now = DateTime.now().toUtc();
    if (alert != null && alert.isActiveAt(now)) {
      _expiryTimer = Timer(alert.expiresAt.difference(now), _syncIncident);
    }
  }

  void _syncIncident() {
    if (!mounted) return;
    final alert = widget.service.mySos;
    final active = alert?.isActiveAt(DateTime.now().toUtc()) == true;
    final ended = _activeIncidentId != null && !active;
    _activeIncidentId = active ? alert!.incidentId : null;
    _scheduleExpiry();
    if (ended) {
      setState(() {
        _editing = false;
        _details.clear();
        _types.clear();
        _recipients.clear();
        _people = 1;
        _location = null;
        _locationRemoved = false;
        _locationGeneration++;
        _error = null;
        _locationError = null;
      });
      // Reuse only the GPS cache, never the previous incident's manual pin.
      unawaited(
        (_locationRead ?? Future<SosLocation?>.value()).then((_) {
          if (mounted) return _initializeLocation();
        }),
      );
    } else {
      _rebuild();
    }
  }

  Future<void> _initializeLocation() async {
    final generation = _locationGeneration;
    final saved = await _locationService.lastKnown();
    if (!mounted || _locationRemoved || generation != _locationGeneration) {
      return;
    }
    if (_location == null && saved != null) setState(() => _location = saved);
    // GPS must never disable the send action, even while permissions or a fix are pending.
    if (_location == null || sosLocationStale(_location!)) {
      await _readLocation();
    }
  }

  @override
  void dispose() {
    _ageTimer?.cancel();
    _expiryTimer?.cancel();
    widget.service.removeListener(_syncIncident);
    _detailsFocus.removeListener(_rebuild);
    _detailsFocus.dispose();
    _details.dispose();
    if (_readingLocation) {
      unawaited(
        SosLocationService.channel.invokeMethod<void>('cancel').catchError((
          Object error,
        ) {
          debugPrint('Cancel GPS: $error');
        }),
      );
    }
    super.dispose();
  }

  Future<SosLocation?> _readLocation() {
    if (_readingLocation) return _locationRead ?? Future.value(_location);
    if (_locationRemoved) return Future.value(null);
    return _locationRead = _captureLocation();
  }

  Future<SosLocation?> _captureLocation() async {
    final generation = _locationGeneration;
    setState(() {
      _readingLocation = true;
      _locationError = null;
    });
    try {
      final result = await _locationService.captureWithFallback();
      if (mounted && !_locationRemoved && generation == _locationGeneration) {
        setState(() => _location = result.location);
        if (result.cached) {
          setState(
            () => _locationError =
                'ยังอ่าน GPS ใหม่ไม่ได้ ใช้พิกัดล่าสุดที่บันทึกไว้',
          );
        }
      }
    } catch (error, stack) {
      debugPrint('SOS location: $error\n$stack');
      if (mounted && !_locationRemoved && generation == _locationGeneration) {
        setState(
          () => _locationError =
              'อ่านตำแหน่งไม่ได้ ลองใหม่หรือส่งโดยไม่แนบพิกัดได้',
        );
      }
    } finally {
      if (mounted) setState(() => _readingLocation = false);
    }
    return _locationRemoved ? null : _location;
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error, stack) {
      debugPrint('SOS action: $error\n$stack');
      if (mounted) {
        setState(
          () => _error = 'ทำรายการไม่สำเร็จ กรุณาตรวจสอบข้อมูลแล้วลองอีกครั้ง',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    // Snapshot the reviewed fix; an automatic GPS result cannot silently change it.
    var reviewedLocation = _locationRemoved ? null : _location;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => SosConfirmationDialog(
        name: _requesterName,
        people: '$_people',
        category: '',
        categories: _types.toList(),
        details: _details.text.trim(),
        location: 'ส่งโดยไม่แนบพิกัด',
        sosLocation: reviewedLocation,
        recipients: _recipients
            .map((id) => widget.service.peers[id] ?? id)
            .toList(),
        translate: (key) => key,
        onRefreshLocation: _locationRemoved
            ? null
            : () async {
                final value = await _readLocation();
                if (value != null) reviewedLocation = value;
                return value;
              },
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() async {
      await widget.service.publishSos(
        name: _requesterName,
        people: _people,
        category: _types.first,
        categories: _types.toList(),
        details: _details.text,
        recipients: Set.of(_recipients),
        location: reviewedLocation,
      );
      if (mounted) setState(() => _editing = false);
    });
  }

  Future<void> _cancel() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const SosCancelDialog(),
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
      final details = '[ยกเลิก: $reason] ${alert.details}';
      await widget.service.publishSos(
        name: alert.name,
        people: alert.people,
        category: alert.category,
        categories: alert.categories,
        details: details.substring(0, details.length.clamp(0, 1000)),
        recipients: widget.service.sosRecipients,
        location: alert.location,
        active: false,
      );
      if (mounted) setState(() => _editing = false);
    });
  }

  Widget _typePicker() {
    const types = [
      EmergencyType.flood,
      EmergencyType.fire,
      EmergencyType.accident,
      EmergencyType.medical,
      EmergencyType.trapped,
      EmergencyType.supplies,
      EmergencyType.other,
    ];
    final accent = RescueTheme.accentFor(context);
    Widget tile(EmergencyType type) {
      final selected = _types.contains(type);
      return Semantics(
        selected: selected,
        button: true,
        label: 'ประเภทเหตุ ${type.shortLabel}',
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(88),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.all(12),
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            backgroundColor: selected ? accent.withValues(alpha: .1) : null,
            side: BorderSide(
              color: selected ? accent : Theme.of(context).dividerColor,
              width: selected ? 2 : 1,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _busy
              ? null
              : () => setState(() {
                  if (selected) {
                    if (_types.length > 1) _types.remove(type);
                  } else if (type == EmergencyType.other) {
                    _types
                      ..clear()
                      ..add(type);
                  } else {
                    _types
                      ..remove(EmergencyType.other)
                      ..add(type);
                  }
                }),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(emergencyIcon(type), color: accent),
                  const Spacer(),
                  if (selected)
                    Icon(Icons.check_circle, size: 20, color: accent),
                ],
              ),
              const SizedBox(height: 8),
              Text(type.shortLabel, style: const TextStyle(fontSize: 14)),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SosStepHeader(
          step: 1,
          title: 'ประเภทเหตุ',
          subtitle: 'เลือกได้หลายประเภท',
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < types.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: i + 1 == types.length
                ? SizedBox(width: double.infinity, child: tile(types[i]))
                : IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: tile(types[i])),
                        const SizedBox(width: 8),
                        Expanded(child: tile(types[i + 1])),
                      ],
                    ),
                  ),
          ),
      ],
    );
  }

  Widget _peoplePicker() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SosStepHeader(
        step: 3,
        title: 'จำนวนผู้ต้องการความช่วยเหลือ',
      ),
      const SizedBox(height: 10),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton.filledTonal(
            tooltip: 'ลดจำนวนคน',
            onPressed: _busy || _people <= 1
                ? null
                : () => setState(() => _people--),
            icon: const Icon(Icons.remove),
          ),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Text(
                '$_people คน',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'เพิ่มจำนวนคน',
            onPressed: _busy || _people >= 999
                ? null
                : () => setState(() => _people++),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        children: [
          for (var i = 1; i <= 5; i++)
            ChoiceChip(
              label: Text(i == 5 ? '5+' : '$i'),
              materialTapTargetSize: MaterialTapTargetSize.padded,
              selected: i == 5 ? _people >= 5 : _people == i,
              onSelected: _busy ? null : (_) => setState(() => _people = i),
            ),
        ],
      ),
    ],
  );

  void _help() => showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    builder: (_) => const Padding(
      padding: EdgeInsets.all(24),
      child: Text(
        'การส่ง SOS ทำงานอย่างไร?\n\nส่งถึงเครื่องใกล้เคียงโดยไม่ต้องมีอินเทอร์เน็ต คำขอที่บันทึกจะประกาศเมื่อเชื่อมต่อเครื่องอื่น '
        'และส่งต่อผ่านเครื่องอื่น การรับข้อความไม่ใช่การยืนยันรับเคสจากเจ้าหน้าที่ '
        'หากยังไม่ได้รับความช่วยเหลือ สามารถส่งซ้ำหรือเพิ่มข้อมูลได้',
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.service, AppPreferences.instance]),
    builder: (context, _) {
      final service = widget.service;
      final current = service.mySos;
      final active = current?.isActiveAt(DateTime.now().toUtc()) == true;
      final formVisible = !active || _editing;
      final deliveries = service.messages.where((m) {
        if (current == null ||
            m.senderId != service.myId ||
            m.type != MessageType.sos) {
          return false;
        }
        try {
          final alert = SosAlert.fromJson(m.text);
          return alert.incidentId == current.incidentId &&
              alert.revision == current.revision;
        } on FormatException {
          return false;
        }
      }).toList();
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'ขอความช่วยเหลือ SOS',
            style: TextStyle(fontSize: 18),
          ),
          automaticallyImplyLeading: !widget.mainTab,
          actions: [
            IconButton(
              tooltip: 'การส่ง SOS ทำงานอย่างไร?',
              onPressed: _help,
              icon: const Icon(Icons.help_outline),
            ),
            IconButton.filledTonal(
              tooltip: 'รายการเหตุ SOS ของฉัน',
              style: IconButton.styleFrom(
                backgroundColor: RescueTheme.accentFor(
                  context,
                ).withValues(alpha: .10),
                foregroundColor: RescueTheme.accentFor(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.history_rounded),
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
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    if (active)
                      SosStatusCard(
                        alert: current!,
                        sending: _busy,
                        deliveries: deliveries,
                        announced: service.currentSosAnnounced,
                        confirmedMessageIds: service.receivedRoutes.keys
                            .toSet(),
                      ),
                    if (formVisible) ...[
                      const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: Text(
                          'เหตุ • ตำแหน่ง • จำนวนคน',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      SosCard(child: _typePicker()),
                      SosCard(
                        child: Column(
                          children: [
                            if (_locationRemoved)
                              const SosStepHeader(step: 2, title: 'ตำแหน่ง')
                            else
                              SosLocationCard(
                                location: _location,
                                reading: _readingLocation,
                                onRefresh: _busy ? () {} : _readLocation,
                                onChanged: (value) => setState(() {
                                  _locationGeneration++;
                                  _location = value;
                                  _locationError = null;
                                }),
                              ),
                            if (_locationError != null && !_locationRemoved)
                              Text(
                                _locationError!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: RescueTheme.mutedFor(context),
                                ),
                              ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                'ไม่แนบพิกัด',
                                style: TextStyle(fontSize: 14),
                              ),
                              value: _locationRemoved,
                              onChanged: _busy
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _locationRemoved = value;
                                        _locationGeneration++;
                                      });
                                      if (!value && !_readingLocation) {
                                        _readLocation();
                                      }
                                    },
                            ),
                          ],
                        ),
                      ),
                      SosCard(child: _peoplePicker()),
                      SosCard(
                        child: TextField(
                          controller: _details,
                          focusNode: _detailsFocus,
                          enabled: !_busy,
                          minLines: _detailsFocus.hasFocus ? 4 : 2,
                          maxLines: 6,
                          maxLength: 1000,
                          onChanged: (_) => setState(() {}),
                          buildCounter:
                              (
                                context, {
                                required currentLength,
                                required isFocused,
                                maxLength,
                              }) => currentLength >= 850
                              ? Text(
                                  '$currentLength/$maxLength',
                                  style: const TextStyle(fontSize: 12),
                                )
                              : null,
                          style: const TextStyle(fontSize: 14),
                          decoration: const InputDecoration(
                            labelText: 'รายละเอียดเพิ่มเติม (ไม่จำเป็น)',
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      SosCard(
                        child: ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: const Text(
                            'ผู้รับเพิ่มเติม',
                            style: TextStyle(fontSize: 14),
                          ),
                          trailing: Badge.count(
                            count: _recipients.length,
                            backgroundColor: RescueTheme.accentFor(context),
                          ),
                          subtitle: active
                              ? const Text(
                                  'ยกเลิก SOS ก่อนเปลี่ยนผู้รับ',
                                  style: TextStyle(fontSize: 12),
                                )
                              : null,
                          children: [
                            if (service.peers.isEmpty)
                              const Text(
                                'คำขอจะประกาศเมื่อเชื่อมต่อเครื่องอื่น',
                              ),
                            for (final peer in service.peers.entries)
                              CheckboxListTile(
                                title: Text(peer.value),
                                subtitle: Text(
                                  service.connectionLabel(peer.key),
                                  style: const TextStyle(fontSize: 12),
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
                    ],

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: formVisible
                            ? kSosRed
                            : const Color(0xFF9A3412),
                        foregroundColor: Colors.white,
                        textStyle: Theme.of(context).textTheme.labelLarge,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed:
                          _busy ||
                              !service.ready ||
                              formVisible && _types.isEmpty
                          ? null
                          : formVisible
                          ? _send
                          : () => _run(service.retry),
                      icon: Icon(
                        formVisible ? Icons.sos_rounded : Icons.refresh,
                      ),
                      label: Text(
                        _busy
                            ? 'กำลังส่ง SOS...'
                            : formVisible
                            ? active
                                  ? 'อัปเดต SOS'
                                  : 'ส่ง SOS'
                            : 'ส่งซ้ำ',
                      ),
                    ),
                    if (active) ...[
                      const SizedBox(height: 6),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          textStyle: Theme.of(context).textTheme.labelLarge,
                          foregroundColor:
                              Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF9BC9FF)
                              : RescueTheme.rescue,
                          side: const BorderSide(color: RescueTheme.rescue),
                        ),
                        onPressed: _busy
                            ? null
                            : () => setState(() => _editing = !_editing),
                        child: Text(
                          _editing
                              ? 'กลับไปหน้าสถานะ'
                              : 'เพิ่มข้อมูล / อัปเดต SOS',
                        ),
                      ),
                      if (!_editing) ...[
                        const SizedBox(height: 6),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor:
                                Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFFFFA6A6)
                                : kSosRed,
                            textStyle: Theme.of(context).textTheme.labelLarge,
                            minimumSize: const Size.fromHeight(48),
                            backgroundColor: kSosRed.withValues(alpha: .08),
                            side: const BorderSide(color: kSosRed),
                          ),
                          onPressed: _busy ? null : _cancel,
                          child: const Text('ยกเลิก SOS'),
                        ),
                      ],
                    ],
                    if (formVisible && !active)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'ตรวจสอบอีกครั้งก่อนส่ง',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
