package com.autoglm.auto_glm_mobile

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.accessibilityservice.GestureDescription
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Path
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
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

    private fun getAllWindowRoots(): List<AccessibilityNodeInfo> {
        val roots = mutableListOf<AccessibilityNodeInfo>()

        rootInActiveWindow?.let { roots.add(it) }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            try {
                windows?.forEach { window ->
                    window.root?.let { roots.add(it) }
                }
            } catch (e: Exception) {
                android.util.Log.w("Accessibility", "getAllWindowRoots error: ${e.message}")
            }
        }

        return roots
    }

    private fun supportsAction(node: AccessibilityNodeInfo, action: Int): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                node.actionList?.any { it.id == action } == true || (node.actions and action) == action
            } else {
                (node.actions and action) == action
            }
        } catch (_: Exception) {
            (node.actions and action) == action
        }
    }

    private fun isProbablyTextInput(node: AccessibilityNodeInfo): Boolean {
        val className = node.className?.toString() ?: ""
        val looksLikeEdit = className.contains("Edit", ignoreCase = true) ||
                className.contains("TextField", ignoreCase = true) ||
                className.contains("Input", ignoreCase = true)

        return node.isEditable || looksLikeEdit || supportsAction(node, AccessibilityNodeInfo.ACTION_SET_TEXT)
    }

    private fun nodeSummary(node: AccessibilityNodeInfo): String {
        val viewId = try {
            node.viewIdResourceName ?: ""
        } catch (_: Exception) {
            ""
        }
        return "class=${node.className} viewId=$viewId focused=${node.isFocused} a11yFocused=${node.isAccessibilityFocused} " +
                "editable=${node.isEditable} visible=${node.isVisibleToUser} enabled=${node.isEnabled} " +
                "supportsSetText=${supportsAction(node, AccessibilityNodeInfo.ACTION_SET_TEXT)} supportsPaste=${supportsAction(node, AccessibilityNodeInfo.ACTION_PASTE)}"
    }
    
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
            val roots = getAllWindowRoots()
            if (roots.isEmpty()) {
                android.util.Log.e("Accessibility", "No root window available")
                return false
            }

            android.util.Log.d("Accessibility", "Root windows count: ${roots.size}")

            // 1) 优先使用输入焦点节点（跨 window）
            val focusedNode = roots.asSequence()
                .mapNotNull { it.findFocus(AccessibilityNodeInfo.FOCUS_INPUT) }
                .firstOrNull()
                ?: roots.asSequence()
                    .mapNotNull { it.findFocus(AccessibilityNodeInfo.FOCUS_ACCESSIBILITY) }
                    .firstOrNull()

            if (focusedNode != null) {
                android.util.Log.d("Accessibility", "Focused node: ${nodeSummary(focusedNode)}")
                if (trySetTextDirect(focusedNode, text)) {
                    android.util.Log.d("Accessibility", "Focused node ACTION_SET_TEXT SUCCESS")
                    return true
                }
                if (tryClipboardPaste(focusedNode, text)) {
                    android.util.Log.d("Accessibility", "Focused node clipboard paste SUCCESS")
                    return true
                }
            }

            // 2) 遍历所有 window，收集可输入候选节点
            val candidates = mutableListOf<AccessibilityNodeInfo>()
            for (root in roots) {
                findTextInputNodesRecursive(root, candidates)
            }
            android.util.Log.d("Accessibility", "Found ${candidates.size} text input candidates")

            val sorted = candidates
                .asSequence()
                .filter { it.isVisibleToUser && it.isEnabled }
                .distinct()
                .sortedByDescending { scoreTextInputCandidate(it) }
                .take(12)
                .toList()

            for (node in sorted) {
                android.util.Log.d("Accessibility", "Trying candidate: ${nodeSummary(node)}")
                if (trySetTextDirect(node, text)) {
                    android.util.Log.d("Accessibility", "Candidate ACTION_SET_TEXT SUCCESS")
                    return true
                }
            }

            for (node in sorted) {
                if (tryClipboardPaste(node, text)) {
                    android.util.Log.d("Accessibility", "Candidate clipboard paste SUCCESS")
                    return true
                }
            }

            android.util.Log.e("Accessibility", "All input methods failed")
            return false
            
        } catch (e: Exception) {
            android.util.Log.e("Accessibility", "inputText error: ${e.message}", e)
            return false
        }
    }

    private fun scoreTextInputCandidate(node: AccessibilityNodeInfo): Int {
        var score = 0
        if (supportsAction(node, AccessibilityNodeInfo.ACTION_SET_TEXT)) score += 120
        if (node.isEditable) score += 90
        if (node.isFocused) score += 80
        if (node.isAccessibilityFocused) score += 60
        if (node.isVisibleToUser) score += 50
        if (node.isEnabled) score += 20
        if (node.isFocusable) score += 10

        val className = node.className?.toString() ?: ""
        if (className.contains("Edit", ignoreCase = true)) score += 15
        if (className.contains("TextField", ignoreCase = true)) score += 15

        return score
    }
    
    /**
     * 找到最合适的可编辑节点
     */
    private fun findBestEditableNode(root: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        // 刷新节点信息
        root.refresh()
        
        // 1. 查找输入焦点
        val inputFocus = root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
        if (inputFocus != null) {
            inputFocus.refresh()
            android.util.Log.d("Accessibility", "Input focus: ${inputFocus.className}, editable: ${inputFocus.isEditable}, focused: ${inputFocus.isFocused}")
            if (inputFocus.isEditable || supportsAction(inputFocus, AccessibilityNodeInfo.ACTION_SET_TEXT)) {
                android.util.Log.d("Accessibility", "Found via FOCUS_INPUT")
                return inputFocus
            }
            // 即使不是 editable，也可能可以接收文本（某些自定义输入框）
            if (inputFocus.className?.contains("Edit") == true) {
                android.util.Log.d("Accessibility", "Found Edit class via FOCUS_INPUT")
                return inputFocus
            }
        }
        
        // 2. 查找可访问性焦点
        val a11yFocus = root.findFocus(AccessibilityNodeInfo.FOCUS_ACCESSIBILITY)
        if (a11yFocus != null) {
            a11yFocus.refresh()
            android.util.Log.d("Accessibility", "A11y focus: ${a11yFocus.className}, editable: ${a11yFocus.isEditable}")
            if (a11yFocus.isEditable || supportsAction(a11yFocus, AccessibilityNodeInfo.ACTION_SET_TEXT)) {
                android.util.Log.d("Accessibility", "Found via FOCUS_ACCESSIBILITY")
                return a11yFocus
            }
        }
        
        // 3. 遍历查找任何可输入节点（包含自定义输入框）
        val editableNodes = mutableListOf<AccessibilityNodeInfo>()
        findTextInputNodesRecursive(root, editableNodes)
        android.util.Log.d("Accessibility", "Found ${editableNodes.size} text input nodes by traversal")
        
        // 优先返回已聚焦的，其次返回可见的
        val sortedNodes = editableNodes
            .asSequence()
            .filter { it.isVisibleToUser && it.isEnabled }
            .sortedByDescending { scoreTextInputCandidate(it) }
            .toList()
        return sortedNodes.firstOrNull()
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
                SystemClock.sleep(50)
            }
            
            // 先点击激活（部分控件需要 click 才能真正获得输入焦点）
            if (!node.isFocused && node.isClickable) {
                node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                SystemClock.sleep(50)
            }
            
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
     * 直接设置文本，不做额外的点击操作
     */
    private fun trySetTextDirect(node: AccessibilityNodeInfo, text: String): Boolean {
        return try {
            android.util.Log.d("Accessibility", "Trying direct ACTION_SET_TEXT...")

            val setTextTarget = findNearestSetTextTarget(node) ?: node
            android.util.Log.d("Accessibility", "SetText target: ${nodeSummary(setTextTarget)}")

            // 尽量先 focus 再 setText
            if (!setTextTarget.isFocused && supportsAction(setTextTarget, AccessibilityNodeInfo.ACTION_FOCUS)) {
                setTextTarget.performAction(AccessibilityNodeInfo.ACTION_FOCUS)
                SystemClock.sleep(30)
            }
            
            // 设置文本
            val arguments = android.os.Bundle()
            arguments.putCharSequence(
                AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE,
                text
            )
            var result = setTextTarget.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, arguments)
            android.util.Log.d("Accessibility", "Direct ACTION_SET_TEXT result: $result")

            // 部分控件需要 click 之后才能成功 setText
            if (!result && setTextTarget.isClickable) {
                setTextTarget.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                SystemClock.sleep(50)
                result = setTextTarget.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, arguments)
                android.util.Log.d("Accessibility", "After click ACTION_SET_TEXT result: $result")
            }
            
            // 如果失败，尝试查找子节点
            if (!result) {
                if (trySetText(setTextTarget, text)) {
                    android.util.Log.d("Accessibility", "Fallback ACTION_SET_TEXT SUCCESS")
                    return true
                }
            }

            result
        } catch (e: Exception) {
            android.util.Log.e("Accessibility", "trySetTextDirect error: ${e.message}")
            false
        }
    }

    private fun findNearestSetTextTarget(node: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        if (supportsAction(node, AccessibilityNodeInfo.ACTION_SET_TEXT)) return node

        // 向下找（优先）
        val queue: java.util.ArrayDeque<AccessibilityNodeInfo> = java.util.ArrayDeque()
        queue.add(node)
        var depth = 0

        while (queue.isNotEmpty() && depth < 3) {
            val size = queue.size
            repeat(size) {
                val cur = queue.removeFirst()
                if (cur != node && supportsAction(cur, AccessibilityNodeInfo.ACTION_SET_TEXT)) return cur
                for (i in 0 until cur.childCount) {
                    val child = cur.getChild(i) ?: continue
                    queue.add(child)
                }
            }
            depth++
        }

        // 向上找
        var parent = node.parent
        var up = 0
        while (parent != null && up < 3) {
            if (supportsAction(parent, AccessibilityNodeInfo.ACTION_SET_TEXT)) return parent
            parent = parent.parent
            up++
        }

        return null
    }
    
    /**
     * 尝试使用剪贴板粘贴
     */
    private fun tryClipboardPaste(node: AccessibilityNodeInfo, text: String): Boolean {
        return try {
            android.util.Log.d("Accessibility", "Trying clipboard paste...")

            val pasteTarget = if (supportsAction(node, AccessibilityNodeInfo.ACTION_PASTE)) {
                node
            } else {
                // 某些自定义输入框 paste 在父/子节点上
                findNearestPasteTarget(node) ?: node
            }
            
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
            if (supportsAction(pasteTarget, AccessibilityNodeInfo.ACTION_FOCUS)) {
                pasteTarget.performAction(AccessibilityNodeInfo.ACTION_FOCUS)
                SystemClock.sleep(30)
            }
            if (pasteTarget.isClickable) {
                pasteTarget.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                SystemClock.sleep(50)
            }
            
            // 执行粘贴
            if (!supportsAction(pasteTarget, AccessibilityNodeInfo.ACTION_PASTE)) {
                android.util.Log.w("Accessibility", "ACTION_PASTE not supported: ${nodeSummary(pasteTarget)}")
                return false
            }

            val result = pasteTarget.performAction(AccessibilityNodeInfo.ACTION_PASTE)
            android.util.Log.d("Accessibility", "ACTION_PASTE result: $result")
            result
        } catch (e: Exception) {
            android.util.Log.e("Accessibility", "tryClipboardPaste error: ${e.message}")
            false
        }
    }

    private fun findNearestPasteTarget(node: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        if (supportsAction(node, AccessibilityNodeInfo.ACTION_PASTE)) return node

        // 向下找
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            val found = findNearestPasteTarget(child)
            if (found != null) return found
        }

        // 向上找一层
        val parent = node.parent
        if (parent != null && supportsAction(parent, AccessibilityNodeInfo.ACTION_PASTE)) return parent

        return null
    }
    
    /**
     * 递归查找可输入节点（包含自定义输入框）
     */
    private fun findTextInputNodesRecursive(node: AccessibilityNodeInfo, result: MutableList<AccessibilityNodeInfo>) {
        if (node.isVisibleToUser && node.isEnabled && isProbablyTextInput(node)) {
            result.add(node)
        }
        
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            findTextInputNodesRecursive(child, result)
        }
    }
    
    /**
     * 清除当前输入框的文字
     */
    fun clearText(): Boolean {
        return inputText("")
    }
    
    // ========== 坐标点击和手势操作 (Android 7.0+) ==========
    
    /**
     * 在指定坐标点击
     * @param x 屏幕X坐标
     * @param y 屏幕Y坐标
     * @param callback 回调函数，返回是否成功
     */
    fun performTap(x: Float, y: Float, callback: (Boolean) -> Unit) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
            android.util.Log.e("Accessibility", "Gesture API requires Android 7.0+")
            callback(false)
            return
        }
        
        try {
            val path = Path()
            path.moveTo(x, y)
            
            val gesture = GestureDescription.Builder()
                .addStroke(GestureDescription.StrokeDescription(path, 0, 50))
                .build()
            
            val result = dispatchGesture(gesture, object : GestureResultCallback() {
                override fun onCompleted(gestureDescription: GestureDescription?) {
                    android.util.Log.d("Accessibility", "Tap completed at ($x, $y)")
                    callback(true)
                }
                
                override fun onCancelled(gestureDescription: GestureDescription?) {
                    android.util.Log.e("Accessibility", "Tap cancelled at ($x, $y)")
                    callback(false)
                }
            }, null)
            
            if (!result) {
                android.util.Log.e("Accessibility", "dispatchGesture returned false")
                callback(false)
            }
        } catch (e: Exception) {
            android.util.Log.e("Accessibility", "Tap error: ${e.message}", e)
            callback(false)
        }
    }
    
    /**
     * 双击
     */
    fun performDoubleTap(x: Float, y: Float, callback: (Boolean) -> Unit) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
            callback(false)
            return
        }
        
        performTap(x, y) { success1 ->
            if (!success1) {
                callback(false)
                return@performTap
            }
            
            Handler(Looper.getMainLooper()).postDelayed({
                performTap(x, y) { success2 ->
                    callback(success2)
                }
            }, 100)
        }
    }
    
    /**
     * 长按
     * @param duration 按压时长（毫秒）
     */
    fun performLongPress(x: Float, y: Float, duration: Long, callback: (Boolean) -> Unit) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
            callback(false)
            return
        }
        
        try {
            val path = Path()
            path.moveTo(x, y)
            
            val gesture = GestureDescription.Builder()
                .addStroke(GestureDescription.StrokeDescription(path, 0, duration))
                .build()
            
            val result = dispatchGesture(gesture, object : GestureResultCallback() {
                override fun onCompleted(gestureDescription: GestureDescription?) {
                    android.util.Log.d("Accessibility", "Long press completed at ($x, $y)")
                    callback(true)
                }
                
                override fun onCancelled(gestureDescription: GestureDescription?) {
                    android.util.Log.e("Accessibility", "Long press cancelled")
                    callback(false)
                }
            }, null)
            
            if (!result) {
                callback(false)
            }
        } catch (e: Exception) {
            android.util.Log.e("Accessibility", "Long press error: ${e.message}", e)
            callback(false)
        }
    }
    
    /**
     * 滑动
     * @param duration 滑动时长（毫秒）
     */
    fun performSwipe(
        startX: Float, startY: Float,
        endX: Float, endY: Float,
        duration: Long,
        callback: (Boolean) -> Unit
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
            callback(false)
            return
        }
        
        try {
            val path = Path()
            path.moveTo(startX, startY)
            path.lineTo(endX, endY)
            
            val gesture = GestureDescription.Builder()
                .addStroke(GestureDescription.StrokeDescription(path, 0, duration))
                .build()
            
            val result = dispatchGesture(gesture, object : GestureResultCallback() {
                override fun onCompleted(gestureDescription: GestureDescription?) {
                    android.util.Log.d("Accessibility", "Swipe completed")
                    callback(true)
                }
                
                override fun onCancelled(gestureDescription: GestureDescription?) {
                    android.util.Log.e("Accessibility", "Swipe cancelled")
                    callback(false)
                }
            }, null)
            
            if (!result) {
                callback(false)
            }
        } catch (e: Exception) {
            android.util.Log.e("Accessibility", "Swipe error: ${e.message}", e)
            callback(false)
        }
    }
    
    /**
     * 执行多点触控手势（例如缩放、旋转）
     * @param paths 多个手指的路径
     * @param durations 每个路径的持续时间
     */
    fun performMultiTouch(
        paths: List<Path>,
        durations: List<Long>,
        callback: (Boolean) -> Unit
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
            callback(false)
            return
        }
        
        if (paths.size != durations.size) {
            android.util.Log.e("Accessibility", "Paths and durations size mismatch")
            callback(false)
            return
        }
        
        try {
            val builder = GestureDescription.Builder()
            
            for (i in paths.indices) {
                builder.addStroke(GestureDescription.StrokeDescription(paths[i], 0, durations[i]))
            }
            
            val gesture = builder.build()
            
            val result = dispatchGesture(gesture, object : GestureResultCallback() {
                override fun onCompleted(gestureDescription: GestureDescription?) {
                    android.util.Log.d("Accessibility", "Multi-touch completed")
                    callback(true)
                }
                
                override fun onCancelled(gestureDescription: GestureDescription?) {
                    android.util.Log.e("Accessibility", "Multi-touch cancelled")
                    callback(false)
                }
            }, null)
            
            if (!result) {
                callback(false)
            }
        } catch (e: Exception) {
            android.util.Log.e("Accessibility", "Multi-touch error: ${e.message}", e)
            callback(false)
        }
    }
}
