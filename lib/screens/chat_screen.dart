import 'package:flutter/material.dart';
import '../services/media_service.dart';
import '../services/message_service.dart';
import '../services/connection_session.dart';
import '../models/message_model.dart';
import '../models/sos_alert.dart';
import '../widgets/location_button.dart';
import '../widgets/media_bubble.dart';
import '../services/media_upload_service.dart';
import '../models/media_model.dart';
import '../widgets/relay_badge.dart';
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
  bool _sending = false;
  String _query = '';
  String _filter = 'all';
  MediaService? get _media =>
      widget.mediaService ?? widget.service.mediaService;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
    } catch (e) {
      final msg = '$e';
      if (mounted && msg != 'No file selected') {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _mediaAction(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Widget _mediaActions(MediaFile media) {
    final uploads = _media!.uploads;
    final job = uploads.forMedia(media.mediaId);
    final active =
        job?.state == UploadState.uploading ||
        job?.state == UploadState.verifying;
    final label = switch (job?.state) {
      UploadState.uploading =>
        'Upload ${(job!.bytes * 100 / media.fileSize).toStringAsFixed(0)}%',
      UploadState.verifying => 'กำลังตรวจไฟล์บน Cloud',
      UploadState.ready => 'Cloud พร้อม • เฉพาะบัญชีคุณ',
      UploadState.failed => 'Upload ไม่สำเร็จ • ลองใหม่',
      UploadState.queued => 'คิว Upload • กดเพื่อเริ่ม',
      null => 'Upload Cloud • เฉพาะบัญชีคุณ',
    };
    return SizedBox(
      width: 240,
      child: Column(
        children: [
          if (active)
            LinearProgressIndicator(
              value: job!.state == UploadState.verifying
                  ? null
                  : job.bytes / media.fileSize,
            ),
          Wrap(
            alignment: WrapAlignment.end,
            children: [
              if (media.senderId == widget.service.myId &&
                  (media.status == MediaStatus.paused ||
                      media.status == MediaStatus.failed ||
                      media.status == MediaStatus.localReady))
                TextButton(
                  onPressed: () =>
                      _mediaAction(() => _media!.retryMedia(media.mediaId)),
                  child: const Text('ส่งใหม่'),
                ),
              TextButton(
                onPressed: active
                    ? null
                    : () => _mediaAction(() async {
                        if (job?.state == UploadState.ready) {
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
                      }),
                child: Text(label),
              ),
            ],
          ),
          if (job?.state == UploadState.failed)
            Text(
              job!.error ?? 'ตรวจสอบอินเทอร์เน็ตแล้วลองใหม่',
              style: const TextStyle(fontSize: 11),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
        ],
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
            final label = media?.fileName ?? m.text;
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
                          ? '${service.peerRoleLabel(widget.peerId)} • ออนไลน์'
                          : '${service.peerRoleLabel(widget.peerId)} • ออฟไลน์',
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'ค้นหาข้อความหรือชื่อไฟล์',
                        ),
                        onChanged: (value) => setState(() => _query = value),
                      ),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _filter,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('ทั้งหมด')),
                        DropdownMenuItem(value: 'text', child: Text('ข้อความ')),
                        DropdownMenuItem(value: 'image', child: Text('รูปภาพ')),
                        DropdownMenuItem(value: 'video', child: Text('วิดีโอ')),
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
                          final time = message.displayTime.toLocal();

                          // ─── Media bubble ─────────────────────────────────────
                          if (message.type == MessageType.media) {
                            final media = _media?.getCached(message.text);
                            return Align(
                              alignment: mine
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Column(
                                  crossAxisAlignment: mine
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  children: [
                                    MediaBubble(media: media, isMine: mine),
                                    if (media != null) _mediaActions(media),
                                    const SizedBox(height: 2),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      child: Text(
                                        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
                                        '${mine ? ' • ${message.statusLabel}' : ''}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.labelSmall,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          // ─── Text / SOS bubble ────────────────────────────
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
                                  if (message.type == MessageType.message &&
                                      service.receivedRoutes[message.id] !=
                                          null)
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
                                    '${mine ? ' • ${message.statusLabel}' : ''}',
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
