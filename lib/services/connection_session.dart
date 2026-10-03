import 'dart:io';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/incoming_notice.dart';

class ConnectionSession {
  static const channel = MethodChannel('com.rmutt.rescuelink/session');
  Future<void> listenForNotifications(
    void Function(IncomingNotice) onOpen,
  ) async {
    if (!Platform.isAndroid) return;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'openNotification' && call.arguments is Map) {
        onOpen(IncomingNotice.fromMap(call.arguments as Map));
      }
    });
    final pending = await channel.invokeMapMethod<String, dynamic>(
      'takeNotification',
    );
    if (pending != null) onOpen(IncomingNotice.fromMap(pending));
  }

  void detachNotifications() {
    if (Platform.isAndroid) channel.setMethodCallHandler(null);
  }

  Future<void> notify(IncomingNotice notice) async {
    if (Platform.isAndroid) {
      await channel.invokeMethod<void>('notify', notice.toMap());
    }
  }

  static Future<void> openDateSettings() async {
    if (Platform.isAndroid) await channel.invokeMethod<void>('dateSettings');
  }

  Future<bool> start() async {
    if (!Platform.isAndroid) return false;
    await Permission.notification.request();
    return await channel.invokeMethod<bool>('start') ?? false;
  }

  Future<void> stop() async {
    if (Platform.isAndroid) await channel.invokeMethod<void>('stop');
  }

  Future<void> alert(String name) async {
    if (Platform.isAndroid) {
      await channel.invokeMethod<void>('alert', {'name': name});
    }
  }

  Future<void> mediaAlert(String name, String messageId) async {
    if (Platform.isAndroid) {
      await channel.invokeMethod<void>('mediaAlert', {
        'name': name,
        'messageId': messageId,
      });
    }
  }
}
