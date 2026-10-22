import 'package:flutter/material.dart';
import '../services/media_service.dart';
import '../services/auth_service.dart';
import '../services/message_service.dart';
import '../services/connection_session.dart';
import '../models/message_model.dart';
import '../models/sos_alert.dart';
import '../models/responder_update.dart';
import '../widgets/location_button.dart';
import '../widgets/media_bubble.dart';
import '../services/media_upload_service.dart';
import '../models/media_model.dart';
import '../widgets/chat_message_bubble.dart';
import '../theme/rescue_theme.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.service,
    required this.peerId,
    this.mediaService,
  });
  final MessageService service;
  final String peerId;
  final MediaService? mediaService;
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final _text = TextEditingController();
  final _focusNode = FocusNode();
  bool _sending = false;
  bool _searchVisible = false;
  String _query = '';
  String _filter = 'all';
  MediaService? get _media =>
      widget.mediaService ?? widget.service.mediaService;
  @override
  void initState() {
    super.initState();
    widget.service.activeChatPeerId = widget.peerId;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.service.activeChatPeerId == widget.peerId) {
      widget.service.activeChatPeerId = null;
    }
    _focusNode.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    final content = _text.text.trim();
    if (content.isEmpty) return;

    final hadFocus = _focusNode.hasFocus;
    _text.clear();
    setState(() => _sending = true);
    try {
      await widget.service.sendTextMessage(
        receiverId: widget.peerId,
        text: content,
      );
    } catch (e, stack) {
      debugPrint('Chat action: $e\n$stack');
      if (mounted) {
        _text.text = content;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ทำรายการไม่สำเร็จ กรุณาลองใหม่')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        if (hadFocus && !_focusNode.hasFocus) {
          _focusNode.requestFocus();
        }
      }
    }
  }

  /// เปิด file picker และส่งสื่อผ่าน MediaService
  Future<void> _sendMedia() async {
    final ms = _media;
    final svc = widget.service;
    if (ms == null || !svc.ready) return;
    setState(() => _sending = true);
    try {
      await ms.pickAndSend(
        senderName: svc.nearbyService.deviceName,
        receiverId: widget.peerId,
      );
    } catch (e, stack) {
      debugPrint('Chat action: $e\n$stack');
      final msg = '$e';
      if (mounted && msg != 'No file selected') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ส่งสื่อไม่สำเร็จ กรุณาลองใหม่')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _mediaAction(Future<void> Function() action) async {
    try {
      await action();
    } catch (e, stack) {
      debugPrint('Chat action: $e\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ทำรายการไม่สำเร็จ กรุณาลองใหม่')),
        );
      }
    }
  }

  ChatDeliveryState _deliveryState(MessageModel message, MediaFile? media) {
    if (message.type != MessageType.media) {
      return message.status == MessageStatus.delivered ||
              message.status == MessageStatus.synced
          ? ChatDeliveryState.delivered
          : ChatDeliveryState.pending;
    }
    if (media == null) return ChatDeliveryState.pending;
    if ((media.status == MediaStatus.failed ||
            media.status == MediaStatus.paused) &&
        (media.retryCount >= 5 || media.errorMessage == 'ไม่พบไฟล์ในเครื่อง')) {
      return ChatDeliveryState.failed;
    }
    final job = _media?.uploads.forMedia(media.mediaId);
    // Cloud retry and transfer ACK are combined into exactly one indicator.
    // Upload failures have nextAttempt and are retryable, never permanent.
    if (job != null && job.state != UploadState.ready) {
      return ChatDeliveryState.pending;
    }
    return media.status == MediaStatus.delivered ||
            media.status == MediaStatus.received ||
            media.status == MediaStatus.cloudReady
        ? ChatDeliveryState.delivered
        : ChatDeliveryState.pending;
  }

  Future<void> _showMediaOptions(MediaFile media) async {
    final uploads = _media!.uploads;
    final ready = uploads.forMedia(media.mediaId)?.state == UploadState.ready;
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (media.senderId == widget.service.myId)
              ListTile(
                leading: const Icon(Icons.refresh_rounded),
                title: const Text('ส่งใหม่'),
                minVerticalPadding: 12,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _mediaAction(() => _media!.retryMedia(media.mediaId));
                },
              ),
            ListTile(
              leading: Icon(
                ready ? Icons.cloud_done_outlined : Icons.cloud_upload_outlined,
              ),
              title: Text(ready ? 'เปิดสื่อจาก Cloud' : 'ซิงก์สื่อไป Cloud'),
              subtitle: !AuthService.instance.signedIn
                  ? const Text('เข้าสู่ระบบเพื่อซิงก์')
                  : null,
              minVerticalPadding: 12,
              onTap: () {
                Navigator.pop(sheetContext);
                _mediaAction(() async {
                  if (ready) {
                    final url = await uploads.accessUrl(media.mediaId);
                    if (!mounted) return;
                    await Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            CloudMediaViewer(url: url, media: media),
                      ),
                    );
                  } else {
                    await uploads.enqueue(media.mediaId);
                  }
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.service, ?_media]),
    builder: (context, _) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final service = widget.service;
      if ((service.unreadCounts[widget.peerId] ?? 0) > 0 &&
          _query.isEmpty &&
          _filter == 'all') {
        final incoming = service.messages
            .where(
              (m) =>
                  m.senderId == widget.peerId && m.receiverId == service.myId,
            )
            .toList();
        if (incoming.isNotEmpty) {
          final lastVisibleId = incoming.last.id;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted ||
                ModalRoute.of(context)?.isCurrent != true ||
                WidgetsBinding.instance.lifecycleState ==
                    AppLifecycleState.paused ||
                WidgetsBinding.instance.lifecycleState ==
                    AppLifecycleState.inactive ||
                WidgetsBinding.instance.lifecycleState ==
                    AppLifecycleState.hidden) {
              return;
            }
            widget.service
                .markConversationRead(widget.peerId, lastVisibleId)
                .catchError((Object e) {
                  debugPrint('Mark chat read: $e');
                });
          });
        }
      }
      final messages = service.messages
          .where(
            (m) =>
                (m.senderId == service.myId && m.receiverId == widget.peerId) ||
                (m.senderId == widget.peerId && m.receiverId == service.myId),
          )
          .where((m) {
            final media = m.type == MessageType.media
                ? _media?.getCached(m.text)
                : null;
            final label =
                media?.fileName ?? ResponderUpdate.cleanDisplay(m.text);
            if (!label.toLowerCase().contains(_query.toLowerCase())) {
              return false;
            }
            return switch (_filter) {
              'image' => media?.isImage == true,
              'video' => media?.isVideo == true,
              'text' => m.type == MessageType.message,
              'pending' =>
                media != null
                    ? media.status != MediaStatus.delivered &&
                          media.status != MediaStatus.received
                    : m.status.index < MessageStatus.delivered.index,
              _ => true,
            };
          })
          .toList()
          .reversed
          .toList();
      final viaName = service.relayViaName(widget.peerId);
      final connectionLabel = service.isOnline(widget.peerId)
          ? '' // ส่งถึงกันโดยตรง: ไม่แสดงอะไร
          : viaName != null
          ? 'ส่งผ่านเครื่อง $viaName'
          : (service.isReachable(widget.peerId)
                ? 'ส่งผ่านเครื่องกลาง'
                : 'รอการเชื่อมต่อ');

      return Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
              tooltip: _searchVisible ? 'ปิดการค้นหา' : 'ค้นหาในแชท',
              icon: Icon(
                _searchVisible ? Icons.close_rounded : Icons.search_rounded,
              ),
              onPressed: () => setState(() {
                _searchVisible = !_searchVisible;
                if (!_searchVisible) {
                  _query = '';
                  _filter = 'all';
                }
              }),
            ),
          ],
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
                      connectionLabel.isEmpty
                          ? service.peerRoleLabel(widget.peerId)
                          : '${service.peerRoleLabel(widget.peerId)} • $connectionLabel',
                      style: TextStyle(
                        fontSize: 12,
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
              if (service.clockSkewPeers.contains(widget.peerId))
                ListTile(
                  leading: const Icon(Icons.schedule),
                  title: const Text('เวลาสองเครื่องไม่ตรงกัน'),
                  subtitle: const Text(
                    'เรียงตามลำดับที่บันทึกในเครื่องนี้แล้ว กรุณาเปิดวันและเวลาอัตโนมัติทั้งสองเครื่อง',
                  ),
                  trailing: TextButton(
                    onPressed: () async {
                      await ConnectionSession.openDateSettings();
                    },
                    child: const Text('ตั้งเวลา'),
                  ),
                ),
              if (_searchVisible)
                ColoredBox(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            style: const TextStyle(fontSize: 15),
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              hintText: 'ค้นหาข้อความหรือชื่อไฟล์',
                            ),
                            onChanged: (value) =>
                                setState(() => _query = value),
                          ),
                        ),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          style: TextStyle(
                            fontSize: 15,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          value: _filter,
                          items: const [
                            DropdownMenuItem(
                              value: 'all',
                              child: Text('ทั้งหมด'),
                            ),
                            DropdownMenuItem(
                              value: 'text',
                              child: Text('ข้อความ'),
                            ),
                            DropdownMenuItem(
                              value: 'image',
                              child: Text('รูปภาพ'),
                            ),
                            DropdownMenuItem(
                              value: 'video',
                              child: Text('วิดีโอ'),
                            ),
                            DropdownMenuItem(
                              value: 'pending',
                              child: Text('ค้างส่ง'),
                            ),
                          ],
                          onChanged: (value) =>
                              setState(() => _filter = value ?? 'all'),
                        ),
                      ],
                    ),
                  ),
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
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        reverse: true,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          final mine = message.senderId == service.myId;
                          final time = message.displayTime.toLocal();
                          final timeFormatted =
                              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                          final sameAsPrevious =
                              index < messages.length - 1 &&
                              messages[index + 1].senderId == message.senderId;
                          final media = message.type == MessageType.media
                              ? _media?.getCached(message.text)
                              : null;
                          return Padding(
                            padding: EdgeInsets.only(
                              top: sameAsPrevious ? 8 : 16,
                            ),
                            child: ChatMessageBubble(
                              key: ValueKey(message.id),
                              isMine: mine,
                              time: timeFormatted,
                              status: _deliveryState(message, media),
                              route: service.receivedRoutes[message.id],
                              peers: {
                                ...service.peers,
                                if (service.myId != null)
                                  service.myId!: 'เครื่องนี้',
                              },
                              onRetry: media == null
                                  ? null
                                  : () => _mediaAction(
                                      () => _media!.retryMedia(media.mediaId),
                                    ),
                              onLongPress: media == null
                                  ? null
                                  : () => _showMediaOptions(media),
                              child: message.type == MessageType.media
                                  ? MediaBubble(media: media, isMine: mine)
                                  : Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SelectableText(
                                          message.type == MessageType.sos
                                              ? SosAlert.fromJson(
                                                  message.text,
                                                ).summary
                                              : ResponderUpdate.cleanDisplay(
                                                  message.text,
                                                ),
                                          style: TextStyle(
                                            fontSize: 15,
                                            height: 1.35,
                                            color: mine
                                                ? Colors.white
                                                : Theme.of(
                                                    context,
                                                  ).colorScheme.onSurface,
                                          ),
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
                        style: const TextStyle(fontSize: 15),
                        focusNode: _focusNode,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: const InputDecoration(
                          labelText: 'พิมพ์ข้อความ',
                          hintText: 'ส่งต่อความห่วงใย…',
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: _media != null
                          ? 'แนบรูป/วิดีโอ'
                          : 'แนบสื่อ (ยังไม่พร้อม)',
                      onPressed: _sending || _media == null ? null : _sendMedia,
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
