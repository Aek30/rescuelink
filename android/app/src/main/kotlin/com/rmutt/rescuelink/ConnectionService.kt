package com.rmutt.rescuelink

import android.app.*
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.*

/** Keeps an existing user-started Nearby session alive while its Activity is paused.
 * Does not restart a Flutter engine after process death or a force-stop. */
class ConnectionService : Service() {
    private var wakeLock: PowerManager.WakeLock? = null
    override fun onBind(intent: Intent?) = null
    override fun onCreate() {
        super.onCreate()
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(NotificationChannel("connection", "การเชื่อมต่อ RescueLink", NotificationManager.IMPORTANCE_LOW))
            manager.createNotificationChannel(NotificationChannel("sos", "คำขอ SOS", NotificationManager.IMPORTANCE_HIGH))
        }
        val open = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, "connection") else Notification.Builder(this)
        val notification = builder.setSmallIcon(android.R.drawable.stat_notify_sync)
            .setContentTitle("RescueLink กำลังเชื่อมต่อ")
            .setContentText("รับส่ง SOS ขณะดับหน้าจอ • เปิดแอปแล้วกดหยุดเพื่อสิ้นสุด")
            .setOngoing(true).setContentIntent(open).build()
        if (Build.VERSION.SDK_INT >= 29) startForeground(1001, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE)
        else startForeground(1001, notification)
        wakeLock = (getSystemService(POWER_SERVICE) as PowerManager).newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "RescueLink:NearbySession").apply { acquire() }
    }
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int = START_NOT_STICKY
    override fun onTaskRemoved(rootIntent: Intent?) {
        stopSelf()
        super.onTaskRemoved(rootIntent)
    }
    override fun onDestroy() {
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        super.onDestroy()
    }
}
