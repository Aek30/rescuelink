import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/incoming_notice.dart';
import 'app_preferences.dart';

class ConnectionSession {
  static const channel = MethodChannel('com.rmutt.rescuelink/session');
  Future<void> listenForNotifications(
    void Function(IncomingNotice) onOpen,
  ) async {
    if (kIsWeb || !Platform.isAndroid) return;
    await updateChannelNames();
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
    if (!kIsWeb && Platform.isAndroid) channel.setMethodCallHandler(null);
  }

  static Future<bool> notificationsAllowed() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    return Permission.notification.isGranted;
  }

  Future<void> updateChannelNames() async {
    if (kIsWeb || !Platform.isAndroid) return;
    final t = AppPreferences.instance.text;
    await channel.invokeMethod<void>('channelNames', {
      'sosChannelName': t('คำขอช่วยเหลือ SOS'),
      'chatChannelName': t('ข้อความใหม่'),
    });
  }

  Future<void> notify(IncomingNotice notice, {int unreadCount = 1}) async {
    if (kIsWeb || !Platform.isAndroid || !await notificationsAllowed()) return;
    final t = AppPreferences.instance.text;
    try {
      await channel.invokeMethod<void>('notify', {
        ...notice.toMap(),
        'notificationId': notice.notificationId,
        'title': notice.sos == null && unreadCount > 1
            ? '$unreadCount ${t('ข้อความใหม่')}'
            : notice.title,
        'unreadCount': unreadCount,
        'sosChannelName': t('คำขอช่วยเหลือ SOS'),
        'chatChannelName': t('ข้อความใหม่'),
        'actionLabel': t(notice.sos == null ? 'เปิดแชต' : 'ดู SOS'),
        'publicTitle': t('ข้อความใหม่'),
      });
    } on PlatformException {
      // Permission may be revoked between checking it and posting.
      if (!await notificationsAllowed()) return;
      rethrow;
    }
  }

  Future<void> cancelNotice(String id) async {
    if (kIsWeb || !Platform.isAndroid) return;
    await channel.invokeMethod<void>('cancel', {'id': id});
  }

  static Future<void> openDateSettings() async {
    if (!kIsWeb && Platform.isAndroid) {
      await channel.invokeMethod<void>('dateSettings');
    }
  }

  Future<bool> start() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    await Permission.notification.request();
    return await channel.invokeMethod<bool>('start') ?? false;
  }

  Future<void> stop() async {
    if (!kIsWeb && Platform.isAndroid) await channel.invokeMethod<void>('stop');
  }
}
