import 'package:flutter/material.dart';
import '../models/message_model.dart';
import '../models/sos_alert.dart';
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
        return 'SOS: ${alert.category.label} - ${alert.details}';
      } catch (_) {
        return 'คำขอ SOS ฉุกเฉิน';
      }
    }
    if (message.type == MessageType.media) {
      final media = s.mediaService?.getCached(message.text);
      if (media?.isVideo == true) return 'ส่งวิดีโอ: ${media!.fileName}';
      if (media != null) return 'ส่งรูปภาพ: ${media.fileName}';
      return 'รูปภาพ / สื่อ';
    }
    return message.text;
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

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${t("ข้อความ")} (${s.totalUnread})',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (v) => setState(() => query = v),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, size: 20),
                    hintText: t("ค้นหาชื่อผู้ติดต่อ"),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(s.error!, style: const TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: s.ready && latest.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.forum_outlined,
                            size: 48,
                            color: isDark ? Colors.grey[600] : Colors.grey[400],
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
                            t("เริ่มการสนทนากับผู้ใช้หรือหน่วยกู้ภัยที่อยู่ใกล้คุณ"),
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          FilledButton.tonal(
                            onPressed: widget.onNearby,
                            child: Text(t("ค้นหาคนใกล้ฉัน")),
                          ),
                        ],
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
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: ids.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      thickness: 0.5,
                      indent: 72,
                      endIndent: 16,
                      color: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF1F5F9),
                    ),
                    itemBuilder: (context, index) {
                      final id = ids[index];
                      final lastMsg = latest[id]!;
                      final unreadCount = s.unreadCounts[id] ?? 0;

                      final isSos = sosPeers.contains(id) ||
                          s.presence[id]?.sos?.isActiveAt(DateTime.now()) == true;
                      final isRescue = s.presence[id]?.rescue == true;

                      // ประเภทผู้ติดต่อ:
                      // ผู้ใช้ทั่วไป: สีเทา
                      // SOS: สีแดง (#FF4D4D)
                      // หน่วยกู้ภัย: สีน้ำเงิน (#3B82F6)
                      final String roleLabel;
                      final Color roleColor;
                      if (isSos) {
                        roleLabel = 'SOS';
                        roleColor = const Color(0xFFFF4D4D);
                      } else if (isRescue) {
                        roleLabel = 'หน่วยกู้ภัย';
                        roleColor = const Color(0xFF3B82F6);
                      } else {
                        roleLabel = 'ผู้ใช้ทั่วไป';
                        roleColor = isDark
                            ? const Color(0xFF9CA3AF)
                            : const Color(0xFF6B7280);
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

                      // การเชื่อมต่อว่าส่งถึงกันโดยตรงหรือเชื่อต่อจากเครื่องอื่น:
                      // การเชื่อมต่อว่าส่งถึงกันโดยตรง: ไม่แสดงอะไร
                      // เชื่อต่อจากเครื่องอื่น: ส่งผ่านเครื่อง (ชื่อเครื่องที่ส่งผ่าน)
                      final relayVia = s.relayViaName(id);

                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 2,
                        ),
                        // ─── บรรทัดที่ 1: Avatar ผู้ติดต่อด้านซ้าย ───────────────
                        leading: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CircleAvatar(
                              radius: 22,
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
                                        : const Color(0xFF64748B)),
                                size: 22,
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
                                      color: isDark
                                          ? const Color(0xFF0F172A)
                                          : Colors.white,
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
                        // ─── บรรทัดที่ 1: ชื่อผู้ติดต่อตัวหนา + เวลาข้อความล่าสุดชิดขวา ───
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                name(id),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1E293B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatTime(lastMsg.displayTime),
                              style: TextStyle(
                                fontSize: 12,
                                color: unreadCount > 0
                                    ? const Color(0xFFEA580C)
                                    : (isDark
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF64748B)),
                                fontWeight: unreadCount > 0
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 3),
                            // ─── บรรทัดที่ 2: ข้อความล่าสุด 1 บรรทัด + Ellipsis + Unread Badge ─
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _messagePreview(lastMsg, s),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: unreadCount > 0
                                          ? (isDark
                                              ? Colors.white
                                              : const Color(0xFF0F172A))
                                          : (isDark
                                              ? const Color(0xFF94A3B8)
                                              : const Color(0xFF64748B)),
                                      fontWeight: unreadCount > 0
                                          ? FontWeight.w500
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                if (unreadCount > 0) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 18,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF4D4D),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '$unreadCount',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            // ─── บรรทัดที่ 3: ประเภทผู้ติดต่อ + สถานะการเชื่อมต่อ + เส้นทาง ────
                            Row(
                              children: [
                                // ประเภทผู้ติดต่อ
                                Text(
                                  roleLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSos
                                        ? FontWeight.bold
                                        : FontWeight.w600,
                                    color: roleColor,
                                  ),
                                ),
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
                                // สถานะการเชื่อมต่อ
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: connectionColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  connectionLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: connectionColor,
                                  ),
                                ),
                                // การเชื่อมต่อว่าส่งถึงกันโดยตรง: ไม่แสดงอะไร
                                // เชื่อต่อจากเครื่องอื่น: ส่งผ่านเครื่อง (ชื่อเครื่องที่ส่งผ่าน)
                                if (relayVia != null && relayVia.isNotEmpty) ...[
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
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? Colors.grey[400]
                                            : const Color(0xFF6B7280),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => ChatScreen(service: s, peerId: id),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      );
    },
  );
}
