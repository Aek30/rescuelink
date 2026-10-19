import 'package:flutter/material.dart';
import '../models/sos_alert.dart';
import '../theme/rescue_theme.dart';
import 'emergency_type_chip.dart';

/// Kept under its original name for callers; presented as a modal bottom sheet.
class SosConfirmationDialog extends StatefulWidget {
  const SosConfirmationDialog({
    super.key,
    required this.name,
    required this.people,
    required this.category,
    required this.details,
    required this.location,
    required this.recipients,
    required this.translate,
    this.categories = const [],
    this.sosLocation,
    this.onRefreshLocation,
  });
  final String name, people, category, details, location;
  final List<String> recipients;
  final String Function(String) translate;
  final List<EmergencyType> categories;
  final SosLocation? sosLocation;
  final Future<SosLocation?> Function()? onRefreshLocation;
  @override
  State<SosConfirmationDialog> createState() => _SosConfirmationDialogState();
}

class _SosConfirmationDialogState extends State<SosConfirmationDialog> {
  late SosLocation? _location = widget.sosLocation;
  bool _reading = false;
  Future<void> _refresh() async {
    setState(() => _reading = true);
    try {
      final value = await widget.onRefreshLocation!();
      if (mounted && value != null) setState(() => _location = value);
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = RescueTheme.mutedFor(context);
    Widget row(String label, Widget value) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: muted)),
          const SizedBox(height: 4),
          value,
        ],
      ),
    );
    final location = _location;
    return Material(
      color: Theme.of(context).brightness == Brightness.dark
          ? RescueTheme.darkSurface
          : Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .85,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Text(
                  'ยืนยันข้อมูล SOS',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      row(
                        'ผู้แจ้ง',
                        Text(
                          widget.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      row(
                        'ประเภทเหตุ',
                        widget.categories.isEmpty
                            ? Text(widget.category)
                            : EmergencyTypeChips(types: widget.categories),
                      ),
                      row(
                        'จำนวนผู้ต้องการความช่วยเหลือ',
                        Text(
                          '${widget.people} คน',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      row(
                        'ตำแหน่ง',
                        location == null
                            ? Text(widget.location)
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sosCoordinates(location),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: muted,
                                    ),
                                  ),
                                  SosLocationStatusChip(location: location),
                                  if (sosLocationStale(location)) ...[
                                    const SosStaleWarning(),
                                    if (widget.onRefreshLocation != null)
                                      OutlinedButton.icon(
                                        onPressed: _reading ? null : _refresh,
                                        icon: const Icon(Icons.my_location),
                                        label: Text(
                                          _reading
                                              ? 'กำลังอัปเดตตำแหน่ง…'
                                              : 'อัปเดตตำแหน่ง',
                                        ),
                                      ),
                                  ],
                                ],
                              ),
                      ),
                      if (widget.details.trim().isNotEmpty)
                        row('รายละเอียดเพิ่มเติม', Text(widget.details)),
                      if (widget.recipients.isNotEmpty)
                        row(
                          'ผู้รับเพิ่มเติม',
                          Text(widget.recipients.join(', ')),
                        ),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: RescueTheme.accentFor(
                            context,
                          ).withValues(alpha: .1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'ประกาศไปยังเครื่องที่เชื่อมต่อและส่งต่อผ่านเครื่องอื่น ถ้าออฟไลน์จะเก็บไว้ส่งทีหลัง',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: kSosRed,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(56),
                      ),
                      onPressed: _reading
                          ? null
                          : () => Navigator.pop(context, true),
                      icon: const Icon(Icons.sos_rounded),
                      label: const Text('ยืนยันส่ง SOS'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('กลับไปแก้ไข'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
