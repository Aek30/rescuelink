import 'package:flutter/material.dart';
import '../services/message_service.dart';
import '../models/message_model.dart';
import '../models/sos_alert.dart';
import '../widgets/location_button.dart';
import '../widgets/relay_badge.dart';
import 'demo_features_screen.dart';
import '../theme/rescue_theme.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.service, required this.peerId});
  final MessageService service;
  final String peerId;
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _text = TextEditingController();
  bool _sending = false;
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await widget.service.sendTextMessage(
        receiverId: widget.peerId,
        text: _text.text,
      );
      if (mounted) _text.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.service,
    builder: (context, _) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final service = widget.service;
      final messages = service.messages
          .where(
            (m) =>
                (m.senderId == service.myId && m.receiverId == widget.peerId) ||
                (m.senderId == widget.peerId && m.receiverId == service.myId),
          )
          .toList()
          .reversed
          .toList();
      return Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              CircleAvatar(
                backgroundColor: isDark
                    ? const Color(0xFF382314)
                    : RescueTheme.peach,
                foregroundColor: isDark
                    ? const Color(0xFFFF9565)
                    : RescueTheme.orangeInk,
                child: const Icon(Icons.person_outline_rounded),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.peers[widget.peerId] ?? 'แชต',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      service.isOnline(widget.peerId)
                          ? 'เชื่อมต่ออยู่'
                          : 'ไม่มีการเชื่อมต่อโดยตรง',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : RescueTheme.mutedFor(context),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF241C15)
                      : RescueTheme.peach.withValues(alpha: .6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  service.isOnline(widget.peerId)
                      ? 'เชื่อมต่อแล้ว • ถึงปลายทาง = บันทึกบนเครื่องรับแล้ว'
                      : 'ไม่มีลิงก์ตรง • ลองส่งผ่านเครื่องใกล้เคียงได้ '
                            '(SENT ยังไม่ยืนยันว่าปลายทางได้รับ)',
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFFCBD5E1)
                        : RescueTheme.mutedFor(context),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ),
              if (service.error != null)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(service.error!),
                ),
              Expanded(
                child: messages.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 40,
                                backgroundColor: isDark
                                    ? const Color(0xFF382314)
                                    : RescueTheme.peach,
                                child: const Icon(
                                  Icons.forum_outlined,
                                  size: 36,
                                  color: RescueTheme.orangeInk,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'ยังไม่มีข้อความ • เริ่มบทสนทนาได้เลย',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white
                                      : RescueTheme.navy,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'ทุกข้อความช่วยให้เราใกล้กันมากขึ้น',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: RescueTheme.mutedFor(context),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.all(12),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          final mine = message.senderId == service.myId;
                          final time = message.timestamp.toLocal();
                          return Align(
                            alignment: mine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.all(12),
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.sizeOf(context).width * .82,
                              ),
                              decoration: BoxDecoration(
                                color: mine
                                    ? (isDark
                                          ? const Color(0xFF55250D)
                                          : RescueTheme.peach)
                                    : (isDark
                                          ? const Color(0xFF161C24)
                                          : Colors.white),
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF283442)
                                      : RescueTheme.border,
                                ),
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(20),
                                  topRight: const Radius.circular(20),
                                  bottomLeft: Radius.circular(mine ? 20 : 5),
                                  bottomRight: Radius.circular(mine ? 5 : 20),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SelectableText(
                                    message.type == MessageType.sos
                                        ? SosAlert.fromJson(
                                            message.text,
                                          ).summary
                                        : message.text,
                                  ),
                                  const SizedBox(height: 4),
                                  if (message.type == MessageType.message)
                                    RelayBadge(
                                      route: service.receivedRoutes[message.id],
                                      peers: {
                                        ...service.peers,
                                        if (service.myId != null)
                                          service.myId!: 'เครื่องนี้',
                                      },
                                    ),
                                  if (message.type == MessageType.sos &&
                                      SosAlert.fromJson(
                                            message.text,
                                          ).location !=
                                          null)
                                    LocationButton(
                                      location: SosAlert.fromJson(
                                        message.text,
                                      ).location!,
                                    ),
                                  Text(
                                    '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} '
                                    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
                                    '${mine ? ' • ${message.status.name.toUpperCase()}' : ''}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelSmall,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF10141C) : Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? const Color(0xFF283442)
                          : RescueTheme.border,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _text,
                        minLines: 1,
                        maxLines: 4,
                        enabled: !_sending,
                        decoration: const InputDecoration(
                          labelText: 'พิมพ์ข้อความ',
                          hintText: 'ส่งต่อความห่วงใย…',
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'แนบสื่อ • จำลอง',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const DemoFeaturesScreen(media: true),
                        ),
                      ),
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                    ),
                    IconButton.filled(
                      onPressed: _sending ? null : _send,
                      style: IconButton.styleFrom(
                        backgroundColor: RescueTheme.orange,
                        foregroundColor: RescueTheme.navy,
                      ),
                      icon: const Icon(Icons.send),
                      tooltip: 'ส่งข้อความ',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
