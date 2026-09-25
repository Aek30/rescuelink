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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.rmutt.rescuelink/session")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "start" -> {
                            val intent = Intent(this, ConnectionService::class.java)
                            if (Build.VERSION.SDK_INT >= 26) startForegroundService(intent) else startService(intent)
                            result.success(true)
                        }
                        "stop" -> { stopService(Intent(this, ConnectionService::class.java)); result.success(null) }
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
