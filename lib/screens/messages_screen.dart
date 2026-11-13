import 'package:flutter/material.dart';
import '../theme/rescue_theme.dart';
import '../models/message_model.dart';
import '../models/sos_alert.dart';
import '../models/responder_update.dart';
import '../services/message_service.dart';
import '../services/app_preferences.dart';
import '../services/chat_sync_service.dart';
import 'chat_screen.dart';

enum _ChatFilter { all, unread, hidden }

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
  var filter = _ChatFilter.all;

  Future<void> _manage(String id, String name) async {
    final t = AppPreferences.instance.t;
    final hidden = filter == _ChatFilter.hidden;
    final delete = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheet) {
        final colors = Theme.of(sheet).colorScheme;
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    name,
                    textAlign: TextAlign.center,
                    style: Theme.of(sheet).textTheme.titleLarge,
                  ),
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: colors.secondaryContainer,
                    child: Icon(
                      hidden
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: colors.onSecondaryContainer,
                    ),
                  ),
                  title: Text(
                    hidden
                        ? t('เลิกซ่อนแชท', 'Unhide chat')
                        : t('ซ่อนแชท', 'Hide chat'),
                  ),
                  subtitle: Text(
                    hidden
                        ? t('ย้ายกลับไปที่ทั้งหมด', 'Move back to All')
                        : t(
                            'ซ่อนบนเครื่องนี้จนกว่าจะมีข้อความใหม่',
                            'Hide on this device until the next message',
                          ),
                  ),
                  onTap: () => Navigator.pop(sheet, false),
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: colors.errorContainer,
                    child: Icon(
                      Icons.delete_outline_rounded,
                      color: colors.onErrorContainer,
                    ),
                  ),
                  title: Text(
                    t('ลบประวัติแชทของฉัน', 'Delete my chat history'),
                    style: TextStyle(color: colors.error),
                  ),
                  subtitle: Text(
                    t(
                      'อีกฝ่ายยังเห็นประวัติของเขา',
                      'The other person keeps their copy',
                    ),
                  ),
                  onTap: () => Navigator.pop(sheet, true),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted || delete == null) return;
    if (delete) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialog) {
          final colors = Theme.of(dialog).colorScheme;
          return AlertDialog(
            icon: Icon(Icons.delete_outline_rounded, color: colors.error),
            title: Text(
              t('ลบประวัติแชทกับ $name?', 'Delete chat history with $name?'),
            ),
            content: Text(
              t(
                'ข้อความ รูป พิกัด และ SOS ในห้องนี้จะหายจากประวัติของคุณ รวมถึงเครื่องอื่นเมื่อซิงก์บัญชีแล้ว การลบนี้ย้อนกลับไม่ได้',
                'Messages, media, locations and SOS entries will disappear from your history and other devices after account sync. This cannot be undone.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog),
                child: Text(t('ยกเลิก', 'Cancel')),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: colors.error,
                  foregroundColor: colors.onError,
                ),
                onPressed: () => Navigator.pop(dialog, true),
                child: Text(t('ลบประวัติ', 'Delete history')),
              ),
            ],
          );
        },
      );
      if (!mounted || confirmed != true) return;
    }
    String result;
    try {
      await widget.service.manageConversation(
        id,
        delete: delete,
        unhide: hidden && !delete,
      );
      result = delete
          ? t('ลบประวัติแชทแล้ว', 'Chat history deleted')
          : hidden
          ? t('ย้ายกลับไปที่ทั้งหมดแล้ว', 'Moved back to All')
          : t('ซ่อนแชทแล้ว', 'Chat hidden');
    } catch (_) {
      result = t(
        'จัดการแชทไม่สำเร็จ กรุณาตรวจสถานะการซิงก์แล้วลองอีกครั้ง',
        'Could not update this chat. Check sync status and try again.',
      );
    }
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result)));
    }
  }

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
            ? 'SOS: ${alert.categoriesLabel} - $details'
            : 'SOS: ${alert.categoriesLabel} (${alert.people} คน)';
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
      if (media?.isVideo == true) return 'ส่งวิดีโอ';
      if (media != null) return 'ส่งรูป';
      return 'รูปภาพ / สื่อ';
    }
    final clean = ResponderUpdate.cleanDisplay(message.text);
    return clean.replaceAll('\r\n', ' ').replaceAll('\n', ' ').trim();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      widget.service,
      AppPreferences.instance,
      ChatSyncCoordinator.instance,
    ]),
    builder: (context, _) {
      final s = widget.service;
      final sync = ChatSyncCoordinator.instance.current;
      final hasCloud = sync?.cloud != null;
      final restoring = hasCloud && sync!.busy;
      final restoreError = hasCloud ? sync!.error : null;
      final t = AppPreferences.instance.text;
      final isDark = Theme.of(context).brightness == Brightness.dark;

      final latest = <String, MessageModel>{};
      final visiblePeers = <String>{};
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
        if (!s.hiddenMessageIds.contains(m.id)) visiblePeers.add(peer);
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
                    switch (filter) {
                      _ChatFilter.hidden => !visiblePeers.contains(id),
                      _ChatFilter.unread =>
                        visiblePeers.contains(id) &&
                            (s.unreadCounts[id] ?? 0) > 0,
                      _ChatFilter.all => visiblePeers.contains(id),
                    },
              )
              .toList()
            ..sort(
              (a, b) =>
                  latest[b]!.displayTime.compareTo(latest[a]!.displayTime),
            );

      final screenBg = isDark
          ? RescueTheme.darkSurface
          : const Color(0xFFFCF7F1);
      final cardBg = isDark ? RescueTheme.darkSurfaceElevated : Colors.white;
      final cardBorderColor = isDark
          ? RescueTheme.darkBorder
          : const Color(0xFFEAE2D8);

      // Routine background sync must not shift the conversation list.
      final showRestoreProgress =
          restoring &&
          restoreError == null &&
          sync.lastSuccess == null &&
          latest.isEmpty;

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
                      border: Border.all(color: cardBorderColor),
                    ),
                    child: TextField(
                      onChanged: (v) => setState(() => query = v),
                      decoration: InputDecoration(
                        prefixIcon: Icon(
                          Icons.search,
                          size: 20,
                          color: isDark
                              ? RescueTheme.darkTextMuted
                              : RescueTheme.muted,
                        ),
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
                  ChipTheme(
                    data: ChipTheme.of(context).copyWith(
                      backgroundColor: cardBg,
                      selectedColor: const Color(0xFFFFEADB),
                      checkmarkColor: RescueTheme.orangeInk,
                      side: BorderSide(color: cardBorderColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final tab in _ChatFilter.values)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(end: 8),
                              child: ChoiceChip(
                                label: Text(switch (tab) {
                                  _ChatFilter.all => t('ทั้งหมด'),
                                  _ChatFilter.unread => t('ยังไม่อ่าน'),
                                  _ChatFilter.hidden =>
                                    AppPreferences.instance.t(
                                      'ซ่อนแล้ว',
                                      'Hidden',
                                    ),
                                }),
                                labelStyle: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: filter == tab
                                      ? RescueTheme.orangeInk
                                      : isDark
                                      ? RescueTheme.darkTextMuted
                                      : RescueTheme.navy,
                                ),
                                selected: filter == tab,
                                onSelected: (_) => setState(() => filter = tab),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!s.ready || showRestoreProgress)
              const LinearProgressIndicator(),
            if (s.error != null)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: kSosRed.withValues(alpha: isDark ? .16 : .07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kSosRed.withValues(alpha: .2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 20,
                      color: isDark ? const Color(0xFFFFB4AB) : kSosRed,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        s.error!,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: isDark ? const Color(0xFFFFB4AB) : kSosRed,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child:
                  s.ready &&
                      visiblePeers.isEmpty &&
                      filter == _ChatFilter.all &&
                      showRestoreProgress
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'กำลังกู้คืนประวัติแชทของบัญชีนี้…',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : s.ready && visiblePeers.isEmpty && filter == _ChatFilter.all
                  ? Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 28,
                          ),
                          decoration: BoxDecoration(
                            color: screenBg,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: cardBorderColor),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircleAvatar(
                                radius: 32,
                                backgroundColor: Color(0xFFFFEADB),
                                child: Icon(
                                  Icons.forum_outlined,
                                  size: 30,
                                  color: RescueTheme.orangeInk,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                t("ยังไม่มีข้อความ"),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? Colors.white
                                      : RescueTheme.navy,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                t(
                                  "เริ่มการสนทนากับผู้ใช้หรือหน่วยกู้ภัยที่อยู่ใกล้คุณ",
                                ),
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.5,
                                  color: isDark
                                      ? RescueTheme.darkTextMuted
                                      : RescueTheme.muted,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              FilledButton.tonal(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFFFEADB),
                                  foregroundColor: RescueTheme.orangeInk,
                                ),
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
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: screenBg,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: cardBorderColor),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircleAvatar(
                                radius: 32,
                                backgroundColor: Color(0xFFFFEADB),
                                child: Icon(
                                  Icons.search_off,
                                  size: 30,
                                  color: RescueTheme.orangeInk,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                filter == _ChatFilter.hidden && query.isEmpty
                                    ? AppPreferences.instance.t(
                                        "ยังไม่มีแชทที่ซ่อน",
                                        "No hidden chats",
                                      )
                                    : t("ไม่พบการสนทนา"),
                                style: TextStyle(
                                  color: isDark
                                      ? RescueTheme.darkTextMuted
                                      : RescueTheme.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(top: 4, bottom: 20),
                      itemCount: ids.length,
                      separatorBuilder: (context, index) => Container(
                        height: 1,
                        margin: const EdgeInsetsDirectional.only(
                          start: 80,
                          end: 16,
                        ),
                        color: cardBorderColor,
                      ),
                      itemBuilder: (context, index) {
                        final id = ids[index];
                        final lastMsg = latest[id]!;
                        final unreadCount = s.unreadCounts[id] ?? 0;

                        final isSos =
                            sosPeers.contains(id) ||
                            s.presence[id]?.sos?.isActiveAt(DateTime.now()) ==
                                true;
                        final isRescue = s.presence[id]?.rescue == true;

                        final String roleLabel;
                        final Color roleColor;
                        final Color roleBgColor;
                        if (isSos) {
                          roleLabel = 'SOS';
                          roleColor = kSosRed;
                          roleBgColor = kSosRed.withValues(
                            alpha: isDark ? .18 : .08,
                          );
                        } else if (isRescue) {
                          roleLabel = 'หน่วยกู้ภัย';
                          roleColor = RescueTheme.rescue;
                          roleBgColor = RescueTheme.rescue.withValues(
                            alpha: isDark ? .18 : .08,
                          );
                        } else {
                          roleLabel = 'ผู้ใช้ทั่วไป';
                          roleColor = isDark
                              ? RescueTheme.darkTextMuted
                              : RescueTheme.navy;
                          roleBgColor = screenBg;
                        }

                        final isConnected = s.isOnline(id) || s.isReachable(id);
                        final connectionColor = isConnected
                            ? const Color(0xFF2E9B6F)
                            : isDark
                            ? RescueTheme.darkTextMuted
                            : RescueTheme.muted;
                        final connectionLabel = isConnected
                            ? 'เชื่อมต่ออยู่'
                            : 'ไม่ได้เชื่อมต่อ';
                        final relayVia = s.relayViaName(id);

                        return Material(
                          color: cardBg,
                          child: InkWell(
                            onLongPress: () => _manage(id, name(id)),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    ChatScreen(service: s, peerId: id),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      CircleAvatar(
                                        radius: 26,
                                        backgroundColor: roleBgColor,
                                        child: Icon(
                                          isSos
                                              ? Icons.person_outline
                                              : isRescue
                                              ? Icons.shield_outlined
                                              : (isConnected
                                                    ? Icons.person
                                                    : Icons.person_outline),
                                          color: roleColor,
                                        ),
                                      ),
                                      if (isConnected)
                                        Positioned(
                                          right: -1,
                                          bottom: -1,
                                          child: Semantics(
                                            label: connectionLabel,
                                            child: Container(
                                              width: 13,
                                              height: 13,
                                              decoration: BoxDecoration(
                                                color: connectionColor,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: cardBg,
                                                  width: 2,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                name(id),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 16,
                                                  height: 1.3,
                                                  color: isDark
                                                      ? Colors.white
                                                      : RescueTheme.navy,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            if (waiting.contains(id)) ...[
                                              Tooltip(
                                                message: 'มีข้อความรอส่ง',
                                                child: Icon(
                                                  Icons.schedule,
                                                  size: 13,
                                                  color: unreadCount > 0
                                                      ? RescueTheme.orangeInk
                                                      : isDark
                                                      ? RescueTheme
                                                            .darkTextMuted
                                                      : RescueTheme.muted,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                            ],
                                            Text(
                                              _formatTime(lastMsg.displayTime),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: unreadCount > 0
                                                    ? RescueTheme.orangeInk
                                                    : isDark
                                                    ? RescueTheme.darkTextMuted
                                                    : RescueTheme.muted,
                                                fontWeight: unreadCount > 0
                                                    ? FontWeight.w600
                                                    : FontWeight.normal,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                _messagePreview(lastMsg, s),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  height: 1.4,
                                                  fontWeight: unreadCount > 0
                                                      ? FontWeight.w600
                                                      : FontWeight.normal,
                                                  color: unreadCount > 0
                                                      ? isDark
                                                            ? Colors.white
                                                            : RescueTheme.navy
                                                      : isDark
                                                      ? RescueTheme
                                                            .darkTextMuted
                                                      : RescueTheme.muted,
                                                ),
                                              ),
                                            ),
                                            if (unreadCount > 0) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                constraints:
                                                    const BoxConstraints(
                                                      minWidth: 22,
                                                      minHeight: 22,
                                                    ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFF067B42,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                alignment: Alignment.center,
                                                child: Text(
                                                  '$unreadCount',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        if (isSos ||
                                            isRescue ||
                                            !isConnected ||
                                            (relayVia != null &&
                                                relayVia.isNotEmpty)) ...[
                                          const SizedBox(height: 7),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 4,
                                            crossAxisAlignment:
                                                WrapCrossAlignment.center,
                                            children: [
                                              if (isSos || isRescue)
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: roleBgColor,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    roleLabel,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: roleColor,
                                                    ),
                                                  ),
                                                ),
                                              if (!isConnected)
                                                Text(
                                                  connectionLabel,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: isDark
                                                        ? RescueTheme
                                                              .darkTextMuted
                                                        : RescueTheme.muted,
                                                  ),
                                                ),
                                              if (relayVia != null &&
                                                  relayVia.isNotEmpty)
                                                Text(
                                                  'ส่งผ่านเครื่อง $relayVia',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: isDark
                                                        ? RescueTheme
                                                              .darkTextMuted
                                                        : RescueTheme.muted,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
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
