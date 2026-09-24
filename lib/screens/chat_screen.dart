import 'package:flutter/material.dart';
import '../services/message_service.dart';

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
        appBar: AppBar(title: Text(service.peers[widget.peerId] ?? 'Chat')),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  service.isOnline(widget.peerId)
                      ? 'Connected • DELIVERED means saved on the other phone'
                      : 'Offline • Messages will send after reconnecting',
                ),
              ),
              if (service.error != null)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(service.error!),
                ),
              Expanded(
                child: messages.isEmpty
                    ? const Center(child: Text('No messages yet'))
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
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.primaryContainer
                                    : Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SelectableText(message.text),
                                  const SizedBox(height: 4),
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
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _text,
                        minLines: 1,
                        maxLines: 4,
                        enabled: !_sending,
                        decoration: const InputDecoration(
                          labelText: 'Message',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _sending ? null : _send,
                      icon: const Icon(Icons.send),
                      tooltip: 'Send',
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
