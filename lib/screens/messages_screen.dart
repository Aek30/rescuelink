import 'package:flutter/material.dart';
import '../models/message_model.dart';
import '../models/sos_alert.dart';
import '../models/responder_update.dart';
import '../services/message_service.dart';
import '../services/app_preferences.dart';
import 'chat_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({
    super.key,
    required this.service,
    required this.onNearby,
  });
  final MessageService service;
  final VoidCallback onNearby;
  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  String query = '';
  bool unreadOnly = false;

  String _formatTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(local.year, local.month, local.day);
    final diffDays = today.difference(messageDay).inDays;

    if (diffDays <= 0) {
      final hh = local.hour.toString().padLeft(2, '0');
      final mm = local.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    } else if (diffDays == 1) {
      return 'เมื่อวาน';
    } else {
      final dd = local.day.toString().padLeft(2, '0');
      final mm = local.month.toString().padLeft(2, '0');
      final thaiYear = ((local.year + 543) % 100).toString().padLeft(2, '0');
      return '$dd/$mm/$thaiYear';
    }
  }

  String _messagePreview(MessageModel message, MessageService s) {
    if (message.type == MessageType.sos) {
      try {
        final alert = SosAlert.fromJson(message.text);
        final details = alert.details.trim();
        return details.isNotEmpty
            ? 'SOS: ${alert.category.label} - $details'
            : 'SOS: ${alert.category.label} (${alert.people} คน)';
      } catch (_) {
        final clean = ResponderUpdate.cleanDisplay(message.text);
        if (clean != message.text && clean.isNotEmpty) {
          return clean.replaceAll('\r\n', ' ').replaceAll('\n', ' ').trim();
        }
        return 'คำขอ SOS ฉุกเฉิน';
      }
    }
    if (message.type == MessageType.media) {
      final media = s.mediaService?.getCached(message.text);
      if (media?.isVideo == true) return 'ส่งวิดีโอ: ${media!.fileName}';
      if (media != null) return 'ส่งรูปภาพ: ${media.fileName}';
      return 'รูปภาพ / สื่อ';
    }
    final clean = ResponderUpdate.cleanDisplay(message.text);
    return clean.replaceAll('\r\n', ' ').replaceAll('\n', ' ').trim();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.service, AppPreferences.instance]),
    builder: (context, _) {
      final s = widget.service;
      final t = AppPreferences.instance.text;
      final isDark = Theme.of(context).brightness == Brightness.dark;

      final latest = <String, MessageModel>{};
      final waiting = <String>{};
      final sosPeers = <String>{};

      for (final m in s.messages) {
        if (![
          MessageType.message,
          MessageType.sos,
          MessageType.media,
        ].contains(m.type)) {
          continue;
        }
        if (m.senderId != s.myId && m.receiverId != s.myId) continue;
        final peer = m.senderId == s.myId ? m.receiverId : m.senderId;
        if (m.type == MessageType.sos) sosPeers.add(peer);
        if (latest[peer] == null ||
            m.displayTime.isAfter(latest[peer]!.displayTime)) {
          latest[peer] = m;
        }
        if (m.senderId == s.myId && m.status == MessageStatus.pending) {
          waiting.add(peer);
        }
      }

      String name(String id) =>
          s.peers[id] ??
          (latest[id]!.senderId == id
              ? latest[id]!.senderName
              : t("ผู้ติดต่อ"));

      final ids =
          latest.keys
              .where(
                (id) =>
                    name(id).toLowerCase().contains(query.toLowerCase()) &&
                    (!unreadOnly || (s.unreadCounts[id] ?? 0) > 0),
              )
              .toList()
            ..sort(
              (a, b) =>
                  latest[b]!.displayTime.compareTo(latest[a]!.displayTime),
            );

      final screenBg = isDark
          ? const Color(0xFF0B0F17)
          : const Color(0xFFF4F6F9);
      final cardBg = isDark ? const Color(0xFF161E2E) : Colors.white;
      final cardBorderColor = isDark
          ? const Color(0xFF263248)
          : const Color(0xFFE2E8F0);

      return ColoredBox(
        color: screenBg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cardBorderColor, width: 1),
                      boxShadow: isDark
                          ? null
                          : [
                              BoxShadow(
                                color: const Color(
                                  0xFF0F172A,
                                ).withValues(alpha: 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: TextField(
                      onChanged: (v) => setState(() => query = v),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search, size: 20),
                        hintText: t("ค้นหาชื่อผู้ติดต่อ"),
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text(t("ทั้งหมด")),
                        selected: !unreadOnly,
                        onSelected: (_) => setState(() => unreadOnly = false),
                      ),
                      ChoiceChip(
                        label: Text(t("ยังไม่อ่าน")),
                        selected: unreadOnly,
                        onSelected: (_) => setState(() => unreadOnly = true),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (!s.ready) const LinearProgressIndicator(),
            if (s.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Text(
                  s.error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            Expanded(
              child: s.ready && latest.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 28,
                          ),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: cardBorderColor,
                              width: 1,
                            ),
                            boxShadow: isDark
                                ? null
                                : [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF0F172A,
                                      ).withValues(alpha: 0.05),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.forum_outlined,
                                size: 48,
                                color: isDark
                                    ? Colors.grey[600]
                                    : Colors.grey[400],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                t("ยังไม่มีข้อความ"),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                t(
                                  "เริ่มการสนทนากับผู้ใช้หรือหน่วยกู้ภัยที่อยู่ใกล้คุณ",
                                ),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 14),
                              FilledButton.tonal(
                                onPressed: widget.onNearby,
                                child: Text(t("ค้นหาคนใกล้ฉัน")),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : s.ready && ids.isEmpty
                  ? Center(
                      child: Text(
                        t("ไม่พบการสนทนา"),
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                      itemCount: ids.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final id = ids[index];
                        final lastMsg = latest[id]!;
                        final unreadCount = s.unreadCounts[id] ?? 0;

                        final isSos =
                            sosPeers.contains(id) ||
                            s.presence[id]?.sos?.isActiveAt(DateTime.now()) ==
                                true;
                        final isRescue = s.presence[id]?.rescue == true;

                        // ประเภทผู้ติดต่อ:
                        // ผู้ใช้ทั่วไป: สีเทา
                        // SOS: สีแดง (#FF4D4D)
                        // หน่วยกู้ภัย: สีน้ำเงิน (#3B82F6)
                        final String roleLabel;
                        final Color roleColor;
                        final Color roleBgColor;
                        if (isSos) {
                          roleLabel = 'SOS';
                          roleColor = const Color(0xFFFF4D4D);
                          roleBgColor = isDark
                              ? const Color(0xFF3B1818)
                              : const Color(0xFFFEF2F2);
                        } else if (isRescue) {
                          roleLabel = 'หน่วยกู้ภัย';
                          roleColor = const Color(0xFF3B82F6);
                          roleBgColor = isDark
                              ? const Color(0xFF17253B)
                              : const Color(0xFFEFF6FF);
                        } else {
                          roleLabel = 'ผู้ใช้ทั่วไป';
                          roleColor = isDark
                              ? const Color(0xFF9CA3AF)
                              : const Color(0xFF64748B);
                          roleBgColor = isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFF1F5F9);
                        }

                        // สถานะการเชื่อมต่อ:
                        // เชื่อมต่ออยู่: สีเขียว (#22C55E)
                        // ไม่ได้เชื่อมต่อ: สีเทา (#9CA3AF)
                        final isConnected = s.isOnline(id) || s.isReachable(id);
                        final connectionColor = isConnected
                            ? const Color(0xFF22C55E)
                            : const Color(0xFF9CA3AF);
                        final connectionLabel = isConnected
                            ? 'เชื่อมต่ออยู่'
                            : 'ไม่ได้เชื่อมต่อ';

                        // การเชื่อมต่อว่าส่งถึงกันโดยตรงหรือเชื่อมต่อจากเครื่องอื่น:
                        final relayVia = s.relayViaName(id);

                        final itemBorderColor = isSos
                            ? (isDark
                                  ? const Color(0xFF7F1D1D)
                                  : const Color(0xFFFECACA))
                            : unreadCount > 0
                            ? (isDark
                                  ? const Color(0xFF7C2D12)
                                  : const Color(0xFFFED7AA))
                            : cardBorderColor;

                        return Container(
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: itemBorderColor,
                              width: 1,
                            ),
                            boxShadow: isDark
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.22,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF0F172A,
                                      ).withValues(alpha: 0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      ChatScreen(service: s, peerId: id),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // ─── Avatar ผู้ติดต่อด้านซ้าย ───────────────
                                    Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        CircleAvatar(
                                          radius: 24,
                                          backgroundColor: isSos
                                              ? (isDark
                                                    ? const Color(0xFF451A1A)
                                                    : const Color(0xFFFFEAEA))
                                              : isRescue
                                              ? (isDark
                                                    ? const Color(0xFF1E2D45)
                                                    : const Color(0xFFEBF3FF))
                                              : (isDark
                                                    ? const Color(0xFF1E293B)
                                                    : const Color(0xFFF1F5F9)),
                                          child: Icon(
                                            isSos
                                                ? Icons.warning_amber_rounded
                                                : isRescue
                                                ? Icons.shield_outlined
                                                : (isConnected
                                                      ? Icons.person
                                                      : Icons.person_outline),
                                            color: isSos
                                                ? const Color(0xFFFF4D4D)
                                                : isRescue
                                                ? const Color(0xFF3B82F6)
                                                : (isDark
                                                      ? const Color(0xFF94A3B8)
                                                      : const Color(
                                                          0xFF64748B,
                                                        )),
                                            size: 23,
                                          ),
                                        ),
                                        if (isSos)
                                          Positioned(
                                            right: -2,
                                            bottom: -2,
                                              child: Container(
                                              padding: const EdgeInsets.all(2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFF4D4D),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: cardBg,
                                                  width: 1.5,
                                                ),
                                              ),
                                              child: const Icon(
                                                Icons.priority_high,
                                                size: 10,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(width: 12),
                                    // ─── เนื้อหาในการ์ดแบ่งสัดส่วนชัดเจน ───
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // บรรทัดที่ 1: ชื่อผู้ติดต่อตัวหนา + เวลาข้อความล่าสุดชิดขวา
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  name(id),
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 15.5,
                                                    color: isDark
                                                        ? Colors.white
                                                        : const Color(
                                                            0xFF0F172A,
                                                          ),
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                _formatTime(
                                                  lastMsg.displayTime,
                                                ),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: unreadCount > 0
                                                      ? const Color(0xFFEA580C)
                                                      : (isDark
                                                            ? const Color(
                                                                0xFF94A3B8,
                                                              )
                                                            : const Color(
                                                                0xFF64748B,
                                                              )),
                                                  fontWeight: unreadCount > 0
                                                      ? FontWeight.w600
                                                      : FontWeight.normal,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 5),
                                          // บรรทัดที่ 2: ข้อความล่าสุด 1 บรรทัด + Unread Badge
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  _messagePreview(lastMsg, s),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 13.5,
                                                    color: unreadCount > 0
                                                        ? (isDark
                                                              ? Colors.white
                                                              : const Color(
                                                                  0xFF0F172A,
                                                                ))
                                                        : (isDark
                                                              ? const Color(
                                                                  0xFF94A3B8,
                                                                )
                                                              : const Color(
                                                                  0xFF475569,
                                                                )),
                                                    fontWeight: unreadCount > 0
                                                        ? FontWeight.w600
                                                        : FontWeight.normal,
                                                  ),
                                                ),
                                              ),
                                              if (unreadCount > 0) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 7,
                                                        vertical: 2,
                                                      ),
                                                  constraints:
                                                      const BoxConstraints(
                                                        minWidth: 20,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFFFF4D4D,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                  ),
                                                  alignment: Alignment.center,
                                                  child: Text(
                                                    '$unreadCount',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Divider(
                                            height: 1,
                                            thickness: 0.7,
                                            color: isDark
                                                ? const Color(0xFF1E293B)
                                                : const Color(0xFFF1F5F9),
                                          ),
                                          const SizedBox(height: 8),
                                          // บรรทัดที่ 3: ป้ายประเภทผู้ติดต่อ + สถานะการเชื่อมต่อ + เส้นทาง
                                          Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: roleBgColor,
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  roleLabel,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: isSos
                                                        ? FontWeight.bold
                                                        : FontWeight.w600,
                                                    color: roleColor,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                width: 6,
                                                height: 6,
                                                decoration: BoxDecoration(
                                                  color: connectionColor,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 5),
                                              Text(
                                                connectionLabel,
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w500,
                                                  color: connectionColor,
                                                ),
                                              ),
                                              if (relayVia != null &&
                                                  relayVia.isNotEmpty) ...[
                                                const SizedBox(width: 6),
                                                Text(
                                                  '•',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: isDark
                                                        ? Colors.grey[600]
                                                        : Colors.grey[400],
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    'ส่งผ่านเครื่อง $relayVia',
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: isDark
                                                          ? Colors.grey[400]
                                                          : const Color(
                                                              0xFF6B7280,
                                                            ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      );
    },
  );
}
