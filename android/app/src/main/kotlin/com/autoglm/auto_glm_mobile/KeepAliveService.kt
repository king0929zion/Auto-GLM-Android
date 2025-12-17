package com.autoglm.auto_glm_mobile

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

/**
 * 保活前台服务
 * 用于防止应用被系统杀死，从而保持无障碍服务的连接
 * 
 * 某些国产 ROM（小米、华为、OPPO、vivo 等）会在应用被划掉后
 * 自动关闭无障碍服务。前台服务可以减少这种情况的发生。
 */
class KeepAliveService : Service() {
    
    companion object {
        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "autoglm_keep_alive"
        private const val CHANNEL_NAME = "AutoGLM 后台运行"
        
        private var isRunning = false
        
        fun isServiceRunning(): Boolean = isRunning
    }
    
    override fun onCreate() {
        super.onCreate()
        isRunning = true
        android.util.Log.d("KeepAliveService", "Service created")
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, createNotification())
        android.util.Log.d("KeepAliveService", "Service started as foreground")
        return START_STICKY
    }
    
    override fun onDestroy() {
        super.onDestroy()
        isRunning = false
        android.util.Log.d("KeepAliveService", "Service destroyed")
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW // 低优先级，不会打扰用户
            ).apply {
                description = "保持 AutoGLM 后台运行，防止无障碍服务被系统关闭"
                setShowBadge(false)
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    private fun createNotification(): Notification {
        // 点击通知打开应用
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            packageManager.getLaunchIntentForPackage(packageName),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("AutoGLM 正在运行")
            .setContentText("无障碍服务已启用，点击返回应用")
            .setSmallIcon(android.R.drawable.ic_menu_info_details)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }
}
