import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/message_model.dart';
import '../services/chat_sync_service.dart';

class ChatHistoryScreen extends StatefulWidget {
  const ChatHistoryScreen({super.key, this.service});
  final ChatSyncService? service;
  @override
  State<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<ChatHistoryScreen> {
  ChatSyncService? get sync =>
      widget.service ?? ChatSyncCoordinator.instance.current;
  Future<void> _action(Future<void> Function() action) async {
    try {
      await action();
      await sync?.refreshStatus();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _edit(MessageModel message) async {
    final controller = TextEditingController(text: message.text);
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('แก้ไขประวัติของฉัน'),
        content: TextField(controller: controller, maxLines: 5),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
    // Let the closing dialog finish using its controller.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    controller.dispose();
    if (text != null) {
      await _action(() => sync!.store.edit(message.id, text: text));
    }
  }

  Future<void> _delete(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบจากประวัติของฉัน?'),
        content: const Text(
          'การลบจะซิงก์กับ Cloud ของบัญชีคุณ ข้อความที่ส่งถึงผู้รับแล้วจะยังอยู่ที่เครื่องผู้รับ',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _action(() => sync!.store.edit(id, delete: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = sync;
    if (service == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('ประวัติข้อความ / Cloud')),
        body: const Center(child: Text('กรุณาเปิดแอปใหม่')),
      );
    }
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Text('ประวัติข้อความ / Cloud'),
          actions: [
            IconButton(
              tooltip: 'ซิงก์ตอนนี้',
              onPressed: service.busy ? null : () => _action(service.sync),
              icon: const Icon(Icons.sync),
            ),
          ],
        ),
        body: Column(
          children: [
            ListTile(
              title: Text(
                service.cloud == null
                    ? 'Guest • เก็บในเครื่อง'
                    : 'ค้างซิงก์ ${service.pending} • ขัดแย้ง ${service.conflicts}',
              ),
              subtitle: Text(
                service.error ??
                    'สำรองข้อความเฉพาะบัญชีคุณเมื่อออนไลน์ การแก้ไข/ลบเป็นประวัติของคุณ ไม่เปลี่ยนข้อความที่ส่งไปแล้ว',
              ),
            ),
            if (service.busy) const LinearProgressIndicator(),
            Expanded(
              child: FutureBuilder<List<Map<String, Object?>>>(
                future: service.store.list(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(child: Text('อ่านประวัติไม่สำเร็จ'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final records = snapshot.data!;
                  if (records.isEmpty) {
                    return const Center(child: Text('ยังไม่มีประวัติข้อความ'));
                  }
                  return ListView.builder(
                    itemCount: records.length,
                    itemBuilder: (context, index) {
                      final row = records[index];
                      final message = MessageModel.fromJson(
                        row['payload'] as String,
                      );
                      final conflict = row['conflict'];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${message.senderName} → ${message.receiverId}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                row['deleted'] == 1
                                    ? 'ลบแล้ว • รอจัดการข้อมูลขัดแย้ง'
                                    : message.text,
                              ),
                              Text('${message.timestamp.toLocal()}'),
                              if (conflict != null) ...[
                                const Text('ข้อมูลขัดแย้งกับ Cloud'),
                                Text(
                                  'Cloud: ${jsonDecode(conflict as String)?['payload']?['text'] ?? 'ไม่มีข้อมูล'}',
                                ),
                                Wrap(
                                  children: [
                                    TextButton(
                                      onPressed: () => _action(
                                        () => service.store.resolve(
                                          message.id,
                                          keepLocal: true,
                                        ),
                                      ),
                                      child: const Text('ใช้ของฉัน'),
                                    ),
                                    TextButton(
                                      onPressed: () => _action(
                                        () => service.store.resolve(
                                          message.id,
                                          keepLocal: false,
                                        ),
                                      ),
                                      child: const Text('ใช้ Cloud'),
                                    ),
                                  ],
                                ),
                              ] else
                                Wrap(
                                  children: [
                                    TextButton(
                                      onPressed: () => _edit(message),
                                      child: const Text('แก้ไขประวัติ'),
                                    ),
                                    TextButton(
                                      onPressed: () => _delete(message.id),
                                      child: const Text('ลบประวัติ'),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
