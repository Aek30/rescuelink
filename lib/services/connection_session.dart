import 'dart:io';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class ConnectionSession {
  static const channel = MethodChannel('com.rmutt.rescuelink/session');
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
}
