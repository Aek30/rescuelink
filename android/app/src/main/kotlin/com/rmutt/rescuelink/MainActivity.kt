package com.rmutt.rescuelink

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.content.ActivityNotFoundException
import android.net.Uri
import android.os.Build
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent

class MainActivity : FlutterActivity() {
    private var locationCapture: LocationCapture? = null
    private var sessionChannel: MethodChannel? = null
    private var notificationReady = false
    private fun notificationData(source: Intent?): Map<String, String>? {
        if (source?.hasExtra("notice_peerId") != true) return null
        return listOf("id", "peerId", "name", "body", "sos").mapNotNull { key ->
            source.getStringExtra("notice_$key")?.let { key to it }
        }.toMap()
    }
    private fun clearNotificationData() {
        for (key in listOf("id", "peerId", "name", "body", "sos")) intent?.removeExtra("notice_$key")
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (notificationReady) {
            notificationData(intent)?.let { sessionChannel?.invokeMethod("openNotification", it) }
            clearNotificationData()
        }
    }
    override fun onStop() {
        locationCapture?.cancel()
        super.onStop()
    }
    override fun onDestroy() {
        locationCapture?.cancel()
        super.onDestroy()
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        locationCapture = LocationCapture(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.rmutt.rescuelink/location")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "capture" -> locationCapture!!.capture(result)
                    "cancel" -> { locationCapture?.cancel(); result.success(null) }
                    else -> result.notImplemented()
                }
            }
        sessionChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.rmutt.rescuelink/session")
        sessionChannel!!.setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "wifiEnabled" -> {
                            val wifi = applicationContext.getSystemService(android.content.Context.WIFI_SERVICE) as android.net.wifi.WifiManager
                            result.success(wifi.isWifiEnabled)
                        }
                        "dateSettings" -> {
                            startActivity(Intent(android.provider.Settings.ACTION_DATE_SETTINGS))
                            result.success(null)
                        }
                        "takeNotification" -> {
                            notificationReady = true
                            result.success(notificationData(intent))
                            clearNotificationData()
                        }
                        "notify" -> {
                            val manager = getSystemService(NotificationManager::class.java)
                            val isSos = call.argument<String>("sos") != null
                            val channelId = if (isSos) "rescue-sos-v2" else "rescue-chat-v2"
                            if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(
                                NotificationChannel(channelId, if (isSos) "คำขอช่วยเหลือ SOS" else "ข้อความใหม่", NotificationManager.IMPORTANCE_HIGH))
                            val id = (call.argument<String>("id") ?: "notice").hashCode() and 0x7fffffff
                            val target = Intent(this, MainActivity::class.java)
                                .setAction("com.rmutt.rescuelink.NOTICE.$id")
                                .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                            for (key in listOf("id", "peerId", "name", "body", "sos")) {
                                call.argument<String>(key)?.let { target.putExtra("notice_$key", it) }
                            }
                            val open = PendingIntent.getActivity(this, id, target, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                            val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, channelId) else Notification.Builder(this)
                            val body = call.argument<String>("body") ?: ""
                            manager.notify("rescuelink-notice", id, builder
                                .setSmallIcon(android.R.drawable.ic_dialog_info)
                                .setContentTitle(call.argument<String>("title"))
                                .setContentText(body).setStyle(Notification.BigTextStyle().bigText(body))
                                .setContentIntent(open).setAutoCancel(true).setOnlyAlertOnce(true)
                                .setPriority(Notification.PRIORITY_HIGH)
                                .addAction(Notification.Action.Builder(null, if (isSos) "ดู SOS" else "เปิดแชต", open).build())
                                .build())
                            result.success(null)
                        }
                        "start" -> {
                            val intent = Intent(this, ConnectionService::class.java)
                            if (Build.VERSION.SDK_INT >= 26) startForegroundService(intent) else startService(intent)
                            result.success(true)
                        }
                        "stop" -> { stopService(Intent(this, ConnectionService::class.java)); result.success(null) }
                        "mediaAlert" -> {
                            val manager = getSystemService(NotificationManager::class.java)
                            if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(NotificationChannel("chat-media", "รูปภาพและวิดีโอ", NotificationManager.IMPORTANCE_DEFAULT))
                            val id = (call.argument<String>("messageId") ?: "media").hashCode() and 0x7fffffff
                            val open = PendingIntent.getActivity(this, id, Intent(this, MainActivity::class.java), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                            val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, "chat-media") else Notification.Builder(this)
                            manager.notify("chat-media", id, builder.setSmallIcon(android.R.drawable.ic_menu_gallery)
                                .setContentTitle("ได้รับรูปภาพหรือวิดีโอแล้ว")
                                .setContentText(call.argument<String>("name") ?: "เปิด RescueLink เพื่อดูสื่อ")
                                .setContentIntent(open).setAutoCancel(true).setOnlyAlertOnce(true).build())
                            result.success(null)
                        }
                        "alert" -> {
                            val manager = getSystemService(NotificationManager::class.java)
                            if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(NotificationChannel("sos", "คำขอ SOS", NotificationManager.IMPORTANCE_HIGH))
                            val open = PendingIntent.getActivity(this, 1, Intent(this, MainActivity::class.java), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                            val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, "sos") else Notification.Builder(this)
                            manager.notify(1002, builder.setSmallIcon(android.R.drawable.ic_dialog_alert).setContentTitle("ได้รับคำขอ SOS")
                                .setContentText(call.argument<String>("name") ?: "เปิด RescueLink เพื่อดูรายละเอียด")
                                .setContentIntent(open).setAutoCancel(true).setPriority(Notification.PRIORITY_HIGH).build())
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) { result.error("session", e.message, null) }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.rmutt.rescuelink/maps")
            .setMethodCallHandler { call, result ->
                if (call.method != "open") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val lat = call.argument<Number>("latitude")?.toDouble()
                val lon = call.argument<Number>("longitude")?.toDouble()
                if (lat == null || lon == null || !lat.isFinite() || !lon.isFinite() || lat !in -90.0..90.0 || lon !in -180.0..180.0) {
                    result.error("coordinates", "Invalid coordinates", null)
                    return@setMethodCallHandler
                }
                try {
                    startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("geo:$lat,$lon?q=$lat,$lon")))
                    result.success(null)
                } catch (e: ActivityNotFoundException) {
                    result.error("unavailable", "No map application", null)
                } catch (e: SecurityException) {
                    result.error("unavailable", "Map application unavailable", null)
                }
            }
    }
}
