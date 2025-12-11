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
        
        // 配置服务 - 添加所有必要的flags
        val info = AccessibilityServiceInfo().apply {
            eventTypes = AccessibilityEvent.TYPES_ALL_MASK
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS or
                    AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS or
                    AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS or
                    AccessibilityServiceInfo.FLAG_REQUEST_ENHANCED_WEB_ACCESSIBILITY or
                    AccessibilityServiceInfo.FLAG_INPUT_METHOD_EDITOR
            notificationTimeout = 100
        }
        serviceInfo = info
        
        android.util.Log.d("Accessibility", "AutoGLM Accessibility Service connected with flags: ${info.flags}")
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
    
    /**
     * 输入文字到当前焦点的输入框
     * 使用多种方法尝试
     */
    fun inputText(text: String): Boolean {
        android.util.Log.d("Accessibility", "=== inputText START: '$text' ===")
        
        try {
            val root = rootInActiveWindow
            if (root == null) {
                android.util.Log.e("Accessibility", "No root window available")
                return false
            }
            
            android.util.Log.d("Accessibility", "Root window package: ${root.packageName}")
            
            // 尝试通过不同方式找到可编辑节点
            val editableNode = findBestEditableNode(root)
            
            if (editableNode == null) {
                android.util.Log.e("Accessibility", "No editable node found")
                return false
            }
            
            android.util.Log.d("Accessibility", "Found editable node: ${editableNode.className}, focused: ${editableNode.isFocused}")
            
            // 方法1: 直接使用 ACTION_SET_TEXT
            if (trySetText(editableNode, text)) {
                android.util.Log.d("Accessibility", "ACTION_SET_TEXT SUCCESS")
                return true
            }
            
            // 方法2: 使用剪贴板粘贴
            if (tryClipboardPaste(editableNode, text)) {
                android.util.Log.d("Accessibility", "Clipboard paste SUCCESS")
                return true
            }
            
            android.util.Log.e("Accessibility", "All input methods failed")
            return false
            
        } catch (e: Exception) {
            android.util.Log.e("Accessibility", "inputText error: ${e.message}", e)
            return false
        }
    }
    
    /**
     * 找到最合适的可编辑节点
     */
    private fun findBestEditableNode(root: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        // 1. 查找输入焦点
        val inputFocus = root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
        if (inputFocus != null && inputFocus.isEditable) {
            android.util.Log.d("Accessibility", "Found via FOCUS_INPUT")
            return inputFocus
        }
        
        // 2. 查找可访问性焦点
        val a11yFocus = root.findFocus(AccessibilityNodeInfo.FOCUS_ACCESSIBILITY)
        if (a11yFocus != null && a11yFocus.isEditable) {
            android.util.Log.d("Accessibility", "Found via FOCUS_ACCESSIBILITY")
            return a11yFocus
        }
        
        // 3. 遍历查找任何可编辑节点
        val editableNodes = mutableListOf<AccessibilityNodeInfo>()
        findEditableNodesRecursive(root, editableNodes)
        android.util.Log.d("Accessibility", "Found ${editableNodes.size} editable nodes by traversal")
        
        // 优先返回已聚焦的
        return editableNodes.sortedByDescending { it.isFocused }.firstOrNull()
    }
    
    /**
     * 尝试使用 ACTION_SET_TEXT
     */
    private fun trySetText(node: AccessibilityNodeInfo, text: String): Boolean {
        return try {
            android.util.Log.d("Accessibility", "Trying ACTION_SET_TEXT...")
            
            // 确保节点获取焦点
            if (!node.isFocused) {
                node.performAction(AccessibilityNodeInfo.ACTION_FOCUS)
                Thread.sleep(100)
            }
            
            // 先点击激活
            node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
            Thread.sleep(100)
            
            // 设置文本
            val arguments = android.os.Bundle()
            arguments.putCharSequence(
                AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE,
                text
            )
            val result = node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, arguments)
            android.util.Log.d("Accessibility", "ACTION_SET_TEXT result: $result")
            result
        } catch (e: Exception) {
            android.util.Log.e("Accessibility", "trySetText error: ${e.message}")
            false
        }
    }
    
    /**
     * 尝试使用剪贴板粘贴
     */
    private fun tryClipboardPaste(node: AccessibilityNodeInfo, text: String): Boolean {
        return try {
            android.util.Log.d("Accessibility", "Trying clipboard paste...")
            
            val context = this.applicationContext
            val clipboard = context.getSystemService(android.content.Context.CLIPBOARD_SERVICE) as? android.content.ClipboardManager
            if (clipboard == null) {
                android.util.Log.e("Accessibility", "ClipboardManager not available")
                return false
            }
            
            // 设置剪贴板内容
            val clip = android.content.ClipData.newPlainText("text", text)
            clipboard.setPrimaryClip(clip)
            android.util.Log.d("Accessibility", "Clipboard set with text")
            
            // 确保节点获取焦点并点击
            node.performAction(AccessibilityNodeInfo.ACTION_FOCUS)
            Thread.sleep(50)
            node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
            Thread.sleep(100)
            
            // 先全选再粘贴
            node.performAction(AccessibilityNodeInfo.ACTION_SELECT_ALL) 
            Thread.sleep(50)
            
            // 执行粘贴
            val result = node.performAction(AccessibilityNodeInfo.ACTION_PASTE)
            android.util.Log.d("Accessibility", "ACTION_PASTE result: $result")
            result
        } catch (e: Exception) {
            android.util.Log.e("Accessibility", "tryClipboardPaste error: ${e.message}")
            false
        }
    }
    
    /**
     * 递归查找可编辑节点
     */
    private fun findEditableNodesRecursive(node: AccessibilityNodeInfo, result: MutableList<AccessibilityNodeInfo>) {
        if (node.isEditable) {
            result.add(node)
        }
        
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            findEditableNodesRecursive(child, result)
        }
    }
    
    /**
     * 清除当前输入框的文字
     */
    fun clearText(): Boolean {
        return inputText("")
    }
}
