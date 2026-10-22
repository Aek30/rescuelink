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
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.graphics.Color
import android.content.pm.PackageManager
import android.Manifest

class MainActivity : FlutterActivity() {
    private var locationCapture: LocationCapture? = null
    private var sessionChannel: MethodChannel? = null
    private var notificationReady = false
    private fun notificationId(key: String) = key.hashCode() and 0x7fffffff

    private fun ensureChannels() {
        if (Build.VERSION.SDK_INT < 26) return
        val manager = getSystemService(NotificationManager::class.java)
        val sos = NotificationChannel("rescue-sos-v3", "คำขอช่วยเหลือ SOS", NotificationManager.IMPORTANCE_HIGH).apply {
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 1000, 400, 1000, 400, 1500)
            enableLights(true)
            lightColor = Color.RED
            setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM),
                AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build())
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        val chat = NotificationChannel("rescue-chat-v3", "ข้อความใหม่", NotificationManager.IMPORTANCE_HIGH).apply {
            lockscreenVisibility = Notification.VISIBILITY_PRIVATE
        }
        manager.createNotificationChannels(listOf(sos, chat))
    }

    // Updating channel names preserves user-controlled sound/importance settings.
    private fun updateChannelNames(sosName: String?, chatName: String?) {
        if (Build.VERSION.SDK_INT < 26) return
        val manager = getSystemService(NotificationManager::class.java)
        for ((id, name) in listOf("rescue-sos-v3" to sosName, "rescue-chat-v3" to chatName)) {
            val channel = manager.getNotificationChannel(id) ?: continue
            if (!name.isNullOrBlank() && channel.name.toString() != name) {
                channel.name = name
                manager.createNotificationChannel(channel)
            }
        }
    }
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
        ensureChannels()
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
                        "channelNames" -> {
                            updateChannelNames(call.argument<String>("sosChannelName"), call.argument<String>("chatChannelName"))
                            result.success(null)
                        }
                        "cancel" -> {
                            val key = call.argument<String>("id")
                                ?: call.argument<String>("peerId")?.let { "chat:$it" }
                            if (key != null) getSystemService(NotificationManager::class.java)
                                .cancel("rescuelink-notice", notificationId(key))
                            result.success(null)
                        }
                        "notify" -> {
                            if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                                result.success(null)
                                return@setMethodCallHandler
                            }
                            val manager = getSystemService(NotificationManager::class.java)
                            val isSos = call.argument<String>("sos") != null
                            val channelId = if (isSos) "rescue-sos-v3" else "rescue-chat-v3"
                            updateChannelNames(call.argument<String>("sosChannelName"), call.argument<String>("chatChannelName"))
                            val key = call.argument<String>("notificationId") ?: call.argument<String>("id") ?: "notice"
                            val id = notificationId(key)
                            val target = Intent(this, MainActivity::class.java)
                                .setAction("com.rmutt.rescuelink.NOTICE.$id")
                                .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                            for (field in listOf("id", "peerId", "name", "body", "sos")) {
                                call.argument<String>(field)?.let { target.putExtra("notice_$field", it) }
                            }
                            val open = PendingIntent.getActivity(this, id, target, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                            val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, channelId) else Notification.Builder(this)
                            val body = call.argument<String>("preview") ?: call.argument<String>("body") ?: ""
                            builder.setSmallIcon(R.drawable.ic_stat_rescuelink)
                                .setContentTitle(call.argument<String>("title"))
                                .setContentText(body).setStyle(Notification.BigTextStyle().bigText(body))
                                .setContentIntent(open).setAutoCancel(true)
                                .setOnlyAlertOnce(!isSos)
                                .setPriority(Notification.PRIORITY_HIGH)
                                .setNumber(call.argument<Int>("unreadCount") ?: 1)
                                .addAction(Notification.Action.Builder(null, call.argument<String>("actionLabel") ?: if (isSos) "ดู SOS" else "เปิดแชต", open).build())
                            if (isSos) {
                                builder.setCategory(Notification.CATEGORY_ALARM).setVisibility(Notification.VISIBILITY_PUBLIC)
                                if (Build.VERSION.SDK_INT < 26) {
                                    builder.setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM),
                                        AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).build())
                                        .setVibrate(longArrayOf(0, 1000, 400, 1000, 400, 1500))
                                        .setLights(Color.RED, 1000, 400)
                                }
                            } else {
                                val publicBuilder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, channelId) else Notification.Builder(this)
                                builder.setVisibility(Notification.VISIBILITY_PRIVATE)
                                    .setPublicVersion(publicBuilder.setSmallIcon(R.drawable.ic_stat_rescuelink)
                                        .setContentTitle(call.argument<String>("publicTitle") ?: "ข้อความใหม่")
                                        .setVisibility(Notification.VISIBILITY_PUBLIC).build())
                                if (Build.VERSION.SDK_INT < 26) builder.setDefaults(Notification.DEFAULT_ALL)
                            }
                            manager.notify("rescuelink-notice", id, builder.build())
                            result.success(null)
                        }
                        "start" -> {
                            val intent = Intent(this, ConnectionService::class.java)
                            if (Build.VERSION.SDK_INT >= 26) startForegroundService(intent) else startService(intent)
                            result.success(true)
                        }
                        "stop" -> { stopService(Intent(this, ConnectionService::class.java)); result.success(null) }
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
