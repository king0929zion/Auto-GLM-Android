package com.autoglm.auto_glm_mobile

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Intent
import android.graphics.Bitmap
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.Display
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * AutoGLM 无障碍服务
 * 提供截图和设备控制能力
 */
class AutoGLMAccessibilityService : AccessibilityService() {
    
    companion object {
        private var instance: AutoGLMAccessibilityService? = null
        private var latestScreenshot: Bitmap? = null
        private var screenshotLatch: CountDownLatch? = null
        
        /**
         * 获取服务实例
         */
        fun getInstance(): AutoGLMAccessibilityService? = instance
        
        /**
         * 服务是否可用
         */
        fun isAvailable(): Boolean = instance != null
        
        /**
         * 通过无障碍服务截图
         */
        fun takeScreenshot(callback: (Bitmap?) -> Unit) {
            val service = instance
            if (service == null) {
                android.util.Log.e("Accessibility", "Service not available")
                callback(null)
                return
            }
            
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
                android.util.Log.e("Accessibility", "takeScreenshot requires Android 11+")
                callback(null)
                return
            }
            
            try {
                service.takeScreenshot(
                    Display.DEFAULT_DISPLAY,
                    service.mainExecutor,
                    object : TakeScreenshotCallback {
                        override fun onSuccess(screenshot: ScreenshotResult) {
                            val bitmap = Bitmap.wrapHardwareBuffer(
                                screenshot.hardwareBuffer,
                                screenshot.colorSpace
                            )
                            screenshot.hardwareBuffer.close()
                            
                            android.util.Log.d("Accessibility", "Screenshot success: ${bitmap?.width}x${bitmap?.height}")
                            callback(bitmap)
                        }
                        
                        override fun onFailure(errorCode: Int) {
                            android.util.Log.e("Accessibility", "Screenshot failed with code: $errorCode")
                            callback(null)
                        }
                    }
                )
            } catch (e: Exception) {
                android.util.Log.e("Accessibility", "Screenshot error: ${e.message}")
                callback(null)
            }
        }
        
        /**
         * 获取当前窗口包名
         */
        fun getCurrentPackage(): String? {
            return instance?.rootInActiveWindow?.packageName?.toString()
        }
    }
    
    private val mainHandler = Handler(Looper.getMainLooper())
    
    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        
        // 配置服务
        val info = AccessibilityServiceInfo().apply {
            eventTypes = AccessibilityEvent.TYPES_ALL_MASK
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS or
                    AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS or
                    AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS
            notificationTimeout = 100
        }
        serviceInfo = info
        
        android.util.Log.d("Accessibility", "AutoGLM Accessibility Service connected")
    }
    
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // 可以记录窗口变化
        event?.let {
            if (it.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
                val packageName = it.packageName?.toString() ?: "unknown"
                android.util.Log.d("Accessibility", "Window changed: $packageName")
            }
        }
    }
    
    override fun onInterrupt() {
        android.util.Log.d("Accessibility", "Service interrupted")
    }
    
    override fun onDestroy() {
        super.onDestroy()
        instance = null
        android.util.Log.d("Accessibility", "Service destroyed")
    }
    
    /**
     * 执行返回操作
     */
    fun performBack(): Boolean {
        return performGlobalAction(GLOBAL_ACTION_BACK)
    }
    
    /**
     * 执行Home操作
     */
    fun performHome(): Boolean {
        return performGlobalAction(GLOBAL_ACTION_HOME)
    }
    
    /**
     * 执行最近任务
     */
    fun performRecents(): Boolean {
        return performGlobalAction(GLOBAL_ACTION_RECENTS)
    }
    
    /**
     * 执行通知栏
     */
    fun performNotifications(): Boolean {
        return performGlobalAction(GLOBAL_ACTION_NOTIFICATIONS)
    }
    
    /**
     * 查找节点
     */
    fun findNodesByText(text: String): List<AccessibilityNodeInfo> {
        val root = rootInActiveWindow ?: return emptyList()
        val nodes = root.findAccessibilityNodeInfosByText(text)
        return nodes ?: emptyList()
    }
    
    /**
     * 通过ID查找节点
     */
    fun findNodeById(viewId: String): AccessibilityNodeInfo? {
        val root = rootInActiveWindow ?: return null
        val nodes = root.findAccessibilityNodeInfosByViewId(viewId)
        return nodes?.firstOrNull()
    }
}
