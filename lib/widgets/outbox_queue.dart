import 'package:flutter/material.dart';

import '../models/message_model.dart';
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
  });

  final List<MessageModel> messages;
  final Map<String, String> peers;
  final bool ready, busy, hasError;
  final VoidCallback onRetry;

  @override
  State<OutboxQueue> createState() => _OutboxQueueState();
}

class _OutboxQueueState extends State<OutboxQueue> {
  int? _filter;
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

  int _group(MessageModel m) => switch (m.status) {
    MessageStatus.pending || MessageStatus.sent => 0,
    MessageStatus.delivered => 1,
    MessageStatus.synced => 2,
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
                          : m.text),
                ),
                const SizedBox(height: 16),
                Text('ถึง ${widget.peers[m.receiverId] ?? m.receiverId}'),
                Text('สร้างเมื่อ ${_date(m.timestamp)}'),
                Text(_status(m)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _status(MessageModel m) => switch (m.status) {
    MessageStatus.pending => 'รอเชื่อมต่อเพื่อส่งข้อความ',
    MessageStatus.sent =>
      'ยังไม่ยืนยันว่าถึงปลายทาง • จะลองส่งซ้ำเมื่อเชื่อมต่อ',
    MessageStatus.delivered => 'เครื่องรับยืนยันแล้ว',
    MessageStatus.synced => 'ซิงก์แล้ว',
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final messages = widget.messages
        .where(
          (m) => m.type == MessageType.message || m.type == MessageType.sos,
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
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        Text(
          'ติดตามข้อความฉุกเฉินและการส่งต่อถึงเครื่องรับ',
          style: TextStyle(color: RescueTheme.mutedFor(context), fontSize: 13),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (var i = 0; i < 3; i++)
              FilterChip(
                selected: _filter == i,
                showCheckmark: false,
                avatar: Icon(
                  _icons[i],
                  size: 17,
                  color: _filter == i
                      ? RescueTheme.orangeInk
                      : RescueTheme.mutedFor(context),
                ),
                label: Text(
                  '${_labels[i]} (${messages.where((m) => _group(m) == i).length})',
                ),
                selectedColor: isDark
                    ? const Color(0xFF382314)
                    : RescueTheme.peach,
                onSelected: (selected) =>
                    setState(() => _filter = selected ? i : null),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _filter == null
              ? 'ทั้งหมด • ${messages.length} ข้อความ'
              : '${_labels[_filter!]} • แตะตัวกรองอีกครั้งเพื่อดูทั้งหมด',
          style: TextStyle(fontSize: 12, color: RescueTheme.mutedFor(context)),
        ),
        const SizedBox(height: 12),
        if (!widget.ready || widget.busy) const LinearProgressIndicator(),
        if (widget.hasError)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'ยังส่งข้อความไม่สำเร็จ ตรวจสอบการเชื่อมต่อแล้วลองอีกครั้ง',
              style: TextStyle(color: RescueTheme.danger),
            ),
          ),
        if (widget.ready && visible.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161C24) : Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.outbox_outlined,
                  size: 40,
                  color: RescueTheme.mutedFor(context),
                ),
                const SizedBox(height: 12),
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
                ),
              ],
            ),
          ),
        for (final m in visible) _card(m),
        const SizedBox(height: 10),
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
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: isDark ? const Color(0xFF283442) : RescueTheme.border,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              Row(
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
              SizedBox(height: 6),
              Text(
                'ระบบจะลองส่งอีกครั้งเมื่อเชื่อมต่อกับอุปกรณ์ใกล้เคียง\nการซิงก์คลาวด์ยังไม่เปิดใช้งาน',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: RescueTheme.mutedFor(context),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isDark ? _darkBackgrounds[group] : _backgrounds[group],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: isDark
                ? color.withValues(alpha: .25)
                : color.withValues(alpha: .12),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _details(m),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: color,
                  foregroundColor: isDark
                      ? RescueTheme.darkBackground
                      : Colors.white,
                  child: Icon(
                    m.type == MessageType.sos
                        ? Icons.sos
                        : Icons.chat_bubble_outline,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _title(m, alert),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${m.type == MessageType.sos ? 'SOS' : 'ข้อความ'} • ${_date(m.timestamp)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: RescueTheme.mutedFor(context),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: .10),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_icons[group], size: 14, color: color),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    _labels[group],
                                    style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            _status(m),
                            style: TextStyle(color: color, fontSize: 11),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'ถึง ${widget.peers[m.receiverId] ?? m.receiverId}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                      if (alert?.location != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '📍 ${alert!.location!.latitude.toStringAsFixed(4)}, ${alert.location!.longitude.toStringAsFixed(4)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      if (alert != null && alert.details.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            alert.details,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: RescueTheme.mutedFor(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
