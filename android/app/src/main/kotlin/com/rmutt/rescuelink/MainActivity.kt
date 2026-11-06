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
import android.media.AudioManager
import android.media.Ringtone
import android.os.Handler
import android.os.Looper
import android.os.Vibrator
import android.os.VibrationEffect
import android.widget.RemoteViews

class MainActivity : FlutterActivity() {
    private companion object {
        const val SOS_CHANNEL = "rescue-sos-v4"
        const val CHAT_CHANNEL = "rescue-chat-v4"
    }
    private var locationCapture: LocationCapture? = null
    private var sessionChannel: MethodChannel? = null
    private var notificationReady = false
    private var sosTone: Ringtone? = null
    private var chatTone: Ringtone? = null
    private var sosFeedbackActive = false
    private val feedbackHandler = Handler(Looper.getMainLooper())
    private val stopFeedback = Runnable { stopSosFeedback() }
    private val stopChat = Runnable { stopChatFeedback() }

    // Resource names keep these URIs stable when numeric resource IDs change.
    private fun soundUri(sos: Boolean) = Uri.parse(
        "android.resource://$packageName/raw/" + if (sos) "rescuelink_sos" else "rescuelink_message"
    )

    private fun stopChatFeedback() {
        feedbackHandler.removeCallbacks(stopChat)
        chatTone?.stop()
        chatTone = null
    }

    private fun playChatFeedback() {
        if (sosFeedbackActive) return
        stopChatFeedback()
        val manager = getSystemService(NotificationManager::class.java)
        if (!manager.areNotificationsEnabled() ||
            manager.currentInterruptionFilter != NotificationManager.INTERRUPTION_FILTER_ALL) return
        val channel = if (Build.VERSION.SDK_INT >= 26) manager.getNotificationChannel(CHAT_CHANNEL) else null
        if (channel != null && channel.importance < NotificationManager.IMPORTANCE_DEFAULT) return
        if ((getSystemService(AUDIO_SERVICE) as AudioManager).ringerMode != AudioManager.RINGER_MODE_NORMAL) return
        val uri = if (Build.VERSION.SDK_INT >= 26) channel?.sound else soundUri(false)
        if (uri == null) return
        feedbackHandler.postDelayed(stopChat, 2_000)
        chatTone = RingtoneManager.getRingtone(this, uri)?.apply {
            audioAttributes = channel?.audioAttributes ?: AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build()
            play()
        }
    }

    private fun stopSosFeedback() {
        sosFeedbackActive = false
        feedbackHandler.removeCallbacks(stopFeedback)
        sosTone?.stop()
        sosTone = null
        (getSystemService(VIBRATOR_SERVICE) as? Vibrator)?.cancel()
    }

    private fun startSosFeedback() {
        stopSosFeedback()
        stopChatFeedback()
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 24 && !manager.areNotificationsEnabled()) return
        if (manager.currentInterruptionFilter != NotificationManager.INTERRUPTION_FILTER_ALL) return
        val channel = if (Build.VERSION.SDK_INT >= 26) manager.getNotificationChannel(SOS_CHANNEL) else null
        if (channel != null && channel.importance < NotificationManager.IMPORTANCE_DEFAULT) return
        val audio = getSystemService(AUDIO_SERVICE) as AudioManager
        if (audio.ringerMode == AudioManager.RINGER_MODE_SILENT) return
        sosFeedbackActive = true
        feedbackHandler.postDelayed(stopFeedback, 10_000)
        if (audio.ringerMode == AudioManager.RINGER_MODE_NORMAL) {
            val uri = if (Build.VERSION.SDK_INT >= 26) channel?.sound
                else soundUri(true)
            if (uri != null) {
                sosTone = RingtoneManager.getRingtone(this, uri)?.apply {
                    audioAttributes = channel?.audioAttributes ?: AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build()
                    if (Build.VERSION.SDK_INT >= 28) isLooping = true
                    play()
                }
            }
        }
        if (channel == null || channel.shouldVibrate()) {
            val vibrator = getSystemService(VIBRATOR_SERVICE) as? Vibrator
            val pattern = longArrayOf(0, 1000, 400, 1000, 400, 1500)
            if (Build.VERSION.SDK_INT >= 26) {
                vibrator?.vibrate(VibrationEffect.createWaveform(pattern, -1))
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(pattern, -1)
            }
        }
    }
    private fun notificationId(key: String) = key.hashCode() and 0x7fffffff

    private fun ensureChannels() {
        if (Build.VERSION.SDK_INT < 26) return
        val manager = getSystemService(NotificationManager::class.java)
        val sos = NotificationChannel(SOS_CHANNEL, "คำขอช่วยเหลือ SOS", NotificationManager.IMPORTANCE_HIGH).apply {
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 1000, 400, 1000, 400, 1500)
            enableLights(true)
            lightColor = Color.RED
            setSound(soundUri(true),
                AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build())
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        val chat = NotificationChannel(CHAT_CHANNEL, "ข้อความใหม่", NotificationManager.IMPORTANCE_HIGH).apply {
            setSound(soundUri(false), AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build())
            lockscreenVisibility = Notification.VISIBILITY_PRIVATE
        }
        // Android channels cannot change their default sound after creation.
        // Carry over blocking, importance and any sound explicitly chosen by the user.
        for ((oldId, replacement) in listOf("rescue-sos-v3" to sos, "rescue-chat-v3" to chat)) {
            if (manager.getNotificationChannel(replacement.id) != null) continue
            val old = manager.getNotificationChannel(oldId) ?: continue
            replacement.importance = old.importance
            replacement.enableVibration(old.shouldVibrate())
            old.vibrationPattern?.let { replacement.vibrationPattern = it }
            val oldDefault = RingtoneManager.getDefaultUri(
                if (oldId == "rescue-sos-v3") RingtoneManager.TYPE_ALARM else RingtoneManager.TYPE_NOTIFICATION)
            val userSound = if (Build.VERSION.SDK_INT >= 30) old.hasUserSetSound()
                else old.sound != oldDefault
            if (userSound || old.sound == null) replacement.setSound(old.sound, old.audioAttributes)
        }
        manager.createNotificationChannels(listOf(sos, chat))
    }

    // Updating channel names preserves user-controlled sound/importance settings.
    private fun updateChannelNames(sosName: String?, chatName: String?) {
        if (Build.VERSION.SDK_INT < 26) return
        val manager = getSystemService(NotificationManager::class.java)
        for ((id, name) in listOf(SOS_CHANNEL to sosName, CHAT_CHANNEL to chatName)) {
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
        stopChatFeedback()
        stopSosFeedback()
        locationCapture?.cancel()
        super.onStop()
    }
    override fun onDestroy() {
        stopChatFeedback()
        stopSosFeedback()
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
                        "startSosFeedback" -> { startSosFeedback(); result.success(null) }
                        "stopSosFeedback" -> { stopSosFeedback(); result.success(null) }
                        "playChatFeedback" -> { playChatFeedback(); result.success(null) }
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
                            val channelId = if (isSos) SOS_CHANNEL else CHAT_CHANNEL
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
                            val close = PendingIntent.getBroadcast(this, id,
                                Intent(this, DismissNoticeReceiver::class.java)
                                    .setAction("com.rmutt.rescuelink.DISMISS.$id")
                                    .putExtra("notification_id", id),
                                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                            val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, channelId) else Notification.Builder(this)
                            val body = call.argument<String>("preview") ?: call.argument<String>("body") ?: ""
                            builder.setSmallIcon(R.drawable.ic_stat_rescuelink)
                                .setContentTitle(call.argument<String>("title"))
                                .setContentText(body)
                                .setContentIntent(open).setAutoCancel(true)
                                .setOnlyAlertOnce(false)
                                .setPriority(Notification.PRIORITY_HIGH)
                                .setNumber(call.argument<Int>("unreadCount") ?: 1)
                                .addAction(Notification.Action.Builder(null, call.argument<String>("actionLabel") ?: if (isSos) "ดู SOS" else "เปิดแชต", open).build())
                                .addAction(Notification.Action.Builder(null, call.argument<String>("closeLabel") ?: "ปิด", close).build())
                                .setCategory(Notification.CATEGORY_MESSAGE)
                                .setColor(if (isSos) Color.rgb(220, 38, 56) else Color.rgb(22, 130, 103))
                                .setStyle(Notification.DecoratedCustomViewStyle())
                            fun bannerView() = RemoteViews(packageName, R.layout.notification_banner).apply {
                                setTextViewText(R.id.notice_title, call.argument<String>("title"))
                                setTextViewText(R.id.notice_body, body)
                                val name = call.argument<String>("name").orEmpty().trim()
                                setTextViewText(R.id.notice_badge, if (isSos) "SOS" else if (name.isEmpty()) "R" else name.substring(0, name.offsetByCodePoints(0, 1)))
                                setTextColor(R.id.notice_badge, if (isSos) Color.rgb(220, 38, 56) else Color.rgb(22, 130, 103))
                                setOnClickPendingIntent(R.id.notice_close, close)
                                setOnClickPendingIntent(R.id.notice_title, open)
                                setOnClickPendingIntent(R.id.notice_body, open)
                                setContentDescription(R.id.notice_close, call.argument<String>("closeLabel") ?: "ปิดแจ้งเตือน")
                            }
                            builder.setCustomHeadsUpContentView(bannerView())
                                .setCustomBigContentView(bannerView())
                            if (isSos) {
                                builder.setVisibility(Notification.VISIBILITY_PUBLIC)
                                if (Build.VERSION.SDK_INT < 26) {
                                    builder.setSound(soundUri(true),
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
                                if (Build.VERSION.SDK_INT < 26) {
                                    builder.setSound(soundUri(false), AudioAttributes.Builder()
                                        .setUsage(AudioAttributes.USAGE_NOTIFICATION).build())
                                        .setDefaults(Notification.DEFAULT_VIBRATE or Notification.DEFAULT_LIGHTS)
                                }
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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.rmutt.rescuelink/video")
            .setMethodCallHandler { call, result ->
                if (call.method != "compress") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val inputPath = call.argument<String>("inputPath")
                val outputPath = call.argument<String>("outputPath")
                if (inputPath.isNullOrBlank() || outputPath.isNullOrBlank()) {
                    result.success(null)
                    return@setMethodCallHandler
                }
                VideoCompressor.compress(this, inputPath, outputPath, result)
            }
    }
}
