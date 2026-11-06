package com.rmutt.rescuelink

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Dismiss only the notification. Do not open the app or alter the SOS. */
class DismissNoticeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (!intent.hasExtra("notification_id")) return
        context.getSystemService(NotificationManager::class.java)
            .cancel("rescuelink-notice", intent.getIntExtra("notification_id", 0))
    }
}
