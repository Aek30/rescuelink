import 'package:flutter/material.dart';

import '../models/message_model.dart';
import '../models/media_model.dart';
import '../services/media_upload_service.dart';
import '../models/sos_alert.dart';
import '../theme/rescue_theme.dart';

/// Delivery receipts and cloud synchronization are distinct states.
class OutboxQueue extends StatefulWidget {
  const OutboxQueue({
    super.key,
    required this.messages,
    required this.peers,
    required this.ready,
    required this.busy,
    required this.onRetry,
    this.hasError = false,
    this.cloudSyncedMessageIds = const {},
    this.mediaFiles = const {},
    this.mediaUploads = const {},
  });

  final List<MessageModel> messages;
  final Map<String, MediaFile> mediaFiles;
  final Map<String, MediaUpload> mediaUploads;
  final Set<String> cloudSyncedMessageIds;
  final Map<String, String> peers;
  final bool ready, busy, hasError;
  final VoidCallback onRetry;

  @override
  State<OutboxQueue> createState() => _OutboxQueueState();
}

class _OutboxQueueState extends State<OutboxQueue> {
  int? _filter;
  final Set<String> _expanded = {};

  static const _labels = ['รอการยืนยัน', 'ถึงเครื่องรับแล้ว', 'ซิงก์แล้ว'];
  static const _icons = [
    Icons.schedule,
    Icons.check_circle_outline,
    Icons.cloud_done_outlined,
  ];
  static const _colors = [
    Color(0xFFC33F43),
    Color(0xFF247C43),
    Color(0xFF2276B8),
  ];
  static const _backgrounds = [
    Color(0xFFFFF0EC),
    Color(0xFFF0F9F0),
    Color(0xFFECF6FF),
  ];
  static const _darkBackgrounds = [
    Color(0xFF231718),
    Color(0xFF14221A),
    Color(0xFF131F2A),
  ];

  bool _cloudReady(MessageModel m) => m.type == MessageType.media
      ? widget.mediaUploads[m.text]?.state == UploadState.ready
      : widget.cloudSyncedMessageIds.contains(m.id);

  int _group(MessageModel m) => _cloudReady(m)
      ? 2
      : switch (m.status) {
          MessageStatus.pending || MessageStatus.sent => 0,
          MessageStatus.delivered => 1,
          MessageStatus.synced => 0,
        };

  String _date(DateTime value) {
    final d = value.toLocal();
    const months = [
      'ม.ค.',
      'ก.พ.',
      'มี.ค.',
      'เม.ย.',
      'พ.ค.',
      'มิ.ย.',
      'ก.ค.',
      'ส.ค.',
      'ก.ย.',
      'ต.ค.',
      'พ.ย.',
      'ธ.ค.',
    ];
    return '${d.day} ${months[d.month - 1]} ค.ศ. ${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _compactDate(DateTime value) {
    final d = value.toLocal();
    const months = [
      'ม.ค.',
      'ก.พ.',
      'มี.ค.',
      'เม.ย.',
      'พ.ค.',
      'มิ.ย.',
      'ก.ค.',
      'ส.ค.',
      'ก.ย.',
      'ต.ค.',
      'พ.ย.',
      'ธ.ค.',
    ];
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${months[d.month - 1]} $hh:$mm';
  }

  SosAlert? _alert(MessageModel m) {
    if (m.type != MessageType.sos) return null;
    try {
      return SosAlert.fromJson(m.text);
    } catch (_) {
      return null;
    }
  }

  String _title(MessageModel m, SosAlert? alert) => m.type == MessageType.sos
      ? alert == null
            ? 'ข้อความ SOS'
            : '${alert.active ? 'ขอความช่วยเหลือ' : 'ยกเลิก SOS'} • ${alert.category.label}'
      : m.type == MessageType.media
      ? '${widget.mediaFiles[m.text]?.isVideo == true ? 'วิดีโอ' : 'รูปภาพ'}: ${widget.mediaFiles[m.text]?.fileName ?? 'ไฟล์สื่อ'}'
      : m.text;

  void _details(MessageModel m) {
    final alert = _alert(m);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'รายละเอียดข้อความ',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                SelectableText(
                  alert?.summary ??
                      (m.type == MessageType.sos
                          ? 'ไม่สามารถอ่านรายละเอียด SOS ได้'
                          : _title(m, alert)),
                ),
                const SizedBox(height: 16),
                Text('ถึง ${widget.peers[m.receiverId] ?? m.receiverId}'),
                Text('สร้างเมื่อ ${_date(m.timestamp)}'),
                Text('สถานะ: ${_status(m)}'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _status(MessageModel m) => _cloudReady(m)
      ? 'สำรองข้อมูลไปยัง Supabase Cloud สำเร็จ • ${m.status == MessageStatus.delivered ? 'เครื่องรับยืนยันแล้ว' : 'ยังไม่ยืนยันการรับที่ปลายทาง'}'
      : m.type == MessageType.media
      ? '${switch (widget.mediaUploads[m.text]?.state) {
          UploadState.uploading => 'กำลังซิงก์ไฟล์ขึ้น Cloud',
          UploadState.verifying => 'กำลังตรวจไฟล์บน Cloud',
          UploadState.failed => 'ซิงก์ไม่สำเร็จ • จะลองใหม่อัตโนมัติ',
          _ => 'อยู่ในคิว • ซิงก์อัตโนมัติเมื่อออนไลน์และเข้าสู่ระบบ',
        }} • ${m.status == MessageStatus.delivered ? 'เครื่องรับยืนยันแล้ว' : 'รอเครื่องรับยืนยัน'}'
      : switch (m.status) {
          MessageStatus.pending => 'รอเชื่อมต่อเพื่อส่งข้อความ',
          MessageStatus.sent =>
            'ยังไม่ยืนยันว่าถึงปลายทาง • จะลองส่งซ้ำเมื่อเชื่อมต่อ',
          MessageStatus.delivered => 'เครื่องรับยืนยันแล้ว',
          MessageStatus.synced =>
            'ข้อมูลเก่าระบุซิงก์แล้ว • ยังไม่มีผล Cloud ยืนยัน',
        };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final messages = widget.messages
        .where(
          (m) =>
              m.type == MessageType.message ||
              m.type == MessageType.sos ||
              m.type == MessageType.media,
        )
        .toList()
        .reversed
        .toList();
    final visible = messages
        .where((m) => _filter == null || _group(m) == _filter)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const Text(
          'ข้อความรอส่ง',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        Text(
          'ติดตามข้อความฉุกเฉินและการส่งต่อถึงเครื่องรับ',
          style: TextStyle(color: RescueTheme.mutedFor(context), fontSize: 13),
        ),
        const SizedBox(height: 12),
        // ─── Status Chips ทั้ง 3 รายการอยู่ในแถวแนวนอนเดียวกัน ──────────────────
        Row(
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: FilterChip(
                  selected: _filter == i,
                  showCheckmark: false,
                  visualDensity: const VisualDensity(
                    horizontal: -4,
                    vertical: -4,
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 3,
                  ),
                  labelPadding: EdgeInsets.zero,
                  label: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _icons[i],
                            size: 13,
                            color: _filter == i
                                ? RescueTheme.orangeInk
                                : RescueTheme.mutedFor(context),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${_labels[i]} (${messages.where((m) => _group(m) == i).length})',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  selectedColor: isDark
                      ? const Color(0xFF382314)
                      : RescueTheme.peach,
                  onSelected: (selected) =>
                      setState(() => _filter = selected ? i : null),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _filter == null
              ? 'ทั้งหมด • ${messages.length} ข้อความ'
              : _filter == 2
              ? 'ซิงก์แล้ว (${messages.where((m) => _group(m) == 2).length}) • สำรองข้อมูลไปยัง Supabase Cloud สำเร็จ'
              : '${_labels[_filter!]} • แตะตัวกรองอีกครั้งเพื่อดูทั้งหมด',
          style: TextStyle(
            fontSize: 11.5,
            color: RescueTheme.mutedFor(context),
          ),
        ),
        const SizedBox(height: 10),
        if (!widget.ready || widget.busy) const LinearProgressIndicator(),
        if (widget.hasError)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'ยังส่งข้อความไม่สำเร็จ ตรวจสอบการเชื่อมต่อแล้วลองอีกครั้ง',
              style: TextStyle(color: RescueTheme.danger),
            ),
          ),
        if (widget.ready && visible.isEmpty)
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161C24) : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.outbox_outlined,
                  size: 36,
                  color: RescueTheme.mutedFor(context),
                ),
                const SizedBox(height: 10),
                Text(
                  _filter == null
                      ? 'ยังไม่มีข้อความในคิว'
                      : 'ไม่มีข้อความ${_labels[_filter!]}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'ข้อความที่คุณส่งจะแสดงสถานะที่นี่',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        for (final m in visible) _card(m),
        const SizedBox(height: 8),
        if (messages.any(
          (m) =>
              m.status == MessageStatus.pending ||
              m.status == MessageStatus.sent,
        ))
          FilledButton.icon(
            onPressed: widget.ready && !widget.busy ? widget.onRetry : null,
            icon: const Icon(Icons.refresh),
            label: Text(
              widget.busy ? 'กำลังลองส่ง…' : 'ลองส่งข้อความที่ค้างอีกครั้ง',
            ),
          ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(
              color: isDark ? const Color(0xFF283442) : RescueTheme.border,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.sync, size: 18),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'ส่งต่ออัตโนมัติเมื่อเชื่อมต่อ',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                'ระบบจะลองส่งอีกครั้งเมื่อเชื่อมต่อกับอุปกรณ์ใกล้เคียง\nสถานะ "ซิงก์แล้ว" หมายถึงจำนวนข้อความที่สำรองข้อมูลไปยัง Supabase Cloud สำเร็จจริง',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  color: RescueTheme.mutedFor(context),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _card(MessageModel m) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final group = _group(m);
    final color = isDark
        ? const [Color(0xFFFFA6A8), Color(0xFF93DCAA), Color(0xFF9CCBFF)][group]
        : _colors[group];
    final alert = _alert(m);
    final isExpanded = _expanded.contains(m.id);
    final receiverName = widget.peers[m.receiverId] ?? m.receiverId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: isDark ? _darkBackgrounds[group] : _backgrounds[group],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isDark
                ? color.withValues(alpha: .25)
                : color.withValues(alpha: .14),
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expanded.remove(m.id);
              } else {
                _expanded.add(m.id);
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: color,
                      foregroundColor: isDark
                          ? RescueTheme.darkBackground
                          : Colors.white,
                      child: Icon(
                        m.type == MessageType.sos
                            ? Icons.sos
                            : m.type == MessageType.media
                            ? Icons.perm_media_outlined
                            : Icons.chat_bubble_outline,
                        size: 15,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  _title(m, alert),
                                  maxLines: isExpanded ? null : 2,
                                  overflow: isExpanded
                                      ? TextOverflow.visible
                                      : TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                    height: 1.25,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                isExpanded
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                size: 18,
                                color: RescueTheme.mutedFor(context),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          // ─── Meta row: สถานะ • วันที่ • ผู้รับ ───
                          Wrap(
                            spacing: 6,
                            runSpacing: 2,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: .12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(_icons[group], size: 11, color: color),
                                    const SizedBox(width: 3),
                                    Text(
                                      _labels[group],
                                      style: TextStyle(
                                        color: color,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 10.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${m.type == MessageType.sos ? 'SOS' : 'ข้อความ'} • ${_compactDate(m.timestamp)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: RescueTheme.mutedFor(context),
                                  height: 1.2,
                                ),
                              ),
                              Text(
                                '• ถึง $receiverName',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.grey[300]
                                      : Colors.grey[800],
                                  fontWeight: FontWeight.w500,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // ─── ข้อมูลเพิ่มเติมเมื่อขยายการ์ด (Expanded state) ─────────────
                if (isExpanded) ...[
                  const SizedBox(height: 8),
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    color: isDark
                        ? const Color(0xFF283442)
                        : const Color(0xFFE2E8F0),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'รายละเอียดข้อความ',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    alert?.summary ??
                        (m.type == MessageType.sos
                            ? 'ไม่สามารถอ่านรายละเอียด SOS ได้'
                            : m.text),
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 13, color: color),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _status(m),
                          style: TextStyle(
                            color: color,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'สร้างเมื่อ ${_date(m.timestamp)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: RescueTheme.mutedFor(context),
                    ),
                  ),
                  if (alert?.location != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '📍 พิกัด: ${alert!.location!.latitude.toStringAsFixed(6)}, ${alert.location!.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                  ],
                  if (alert != null && alert.details.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'รายละเอียด: ${alert.details}',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _details(m),
                      icon: const Icon(Icons.open_in_new, size: 13),
                      label: const Text(
                        'เปิดหน้าต่างเต็ม',
                        style: TextStyle(fontSize: 11),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
