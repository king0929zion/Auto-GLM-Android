# Auto-GLM-Android 技术架构文档

## 📋 目录

- [权限方案分析](#权限方案分析)
- [核心架构设计](#核心架构设计)
- [设备控制降级策略](#设备控制降级策略)
- [功能实现详解](#功能实现详解)
- [最佳实践建议](#最佳实践建议)

---

## 🔐 权限方案分析

### 权限方案对比

本项目采用 **双权限互补方案**：无障碍服务 + Shizuku，两者各有优势，互为补充。

| 维度 | 无障碍服务 | Shizuku | 推荐方案 |
|-----|----------|---------|---------|
| **用户体验** | ⭐⭐⭐⭐⭐ 一次授权永久有效 | ⭐⭐⭐ 重启后需重新激活 | 优先无障碍 |
| **权限获取** | ⭐⭐⭐⭐ 系统设置直接开启 | ⭐⭐ 需要ADB或无线调试 | 优先无障碍 |
| **功能覆盖** | ⭐⭐⭐⭐ 覆盖大部分需求 | ⭐⭐⭐⭐⭐ 完整系统级控制 | Shizuku作补充 |
| **系统版本** | ⭐⭐⭐ 截图需Android 11+ | ⭐⭐⭐⭐⭐ 支持Android 9+ | Shizuku兼容性更好 |
| **稳定性** | ⭐⭐⭐⭐⭐ 非常稳定 | ⭐⭐⭐⭐ 较稳定，偶尔需重启 | 优先无障碍 |
| **中文输入** | ⭐⭐⭐⭐⭐ 完美支持 | ⭐⭐⭐ 需安装ADB Keyboard | 优先无障碍 |

### 无障碍服务能力清单

✅ **可以实现的功能**：

| 功能 | API | Android版本要求 | 实现质量 |
|-----|-----|----------------|---------|
| **截图** | `takeScreenshot()` | Android 11+ | ⭐⭐⭐⭐⭐ |
| **文本输入** | `ACTION_SET_TEXT` | Android 5+ | ⭐⭐⭐⭐⭐ |
| **剪贴板粘贴** | `ACTION_PASTE` | Android 5+ | ⭐⭐⭐⭐ |
| **坐标点击** | `GestureDescription + dispatchGesture()` | Android 7+ | ⭐⭐⭐⭐⭐ |
| **滑动手势** | `GestureDescription + Path` | Android 7+ | ⭐⭐⭐⭐⭐ |
| **长按** | `GestureDescription (duration控制)` | Android 7+ | ⭐⭐⭐⭐⭐ |
| **双击** | `GestureDescription (两次点击)` | Android 7+ | ⭐⭐⭐⭐⭐ |
| **多点触控** | `GestureDescription (多个Stroke)` | Android 7+ | ⭐⭐⭐⭐ |
| **返回键** | `performGlobalAction(GLOBAL_ACTION_BACK)` | Android 4.1+ | ⭐⭐⭐⭐⭐ |
| **Home键** | `performGlobalAction(GLOBAL_ACTION_HOME)` | Android 4.1+ | ⭐⭐⭐⭐⭐ |
| **最近任务** | `performGlobalAction(GLOBAL_ACTION_RECENTS)` | Android 4.1+ | ⭐⭐⭐⭐⭐ |
| **UI元素查找** | `findAccessibilityNodeInfosByText/ViewId` | Android 4.0+ | ⭐⭐⭐⭐⭐ |
| **点击UI元素** | `node.performAction(ACTION_CLICK)` | Android 4.0+ | ⭐⭐⭐⭐⭐ |

❌ **无法实现的功能**：
- 获取前台应用包名（需要USAGE_STATS权限或Shizuku dumpsys）
- Android 7.0 以下的坐标操作（GestureDescription API 在 Android 7.0 引入）

### Shizuku能力清单

✅ **Shizuku提供的核心能力**：

| 功能 | 实现方式 | 用途 |
|-----|---------|-----|
| **注入触摸事件** | `InputManager.injectInputEvent()` | 任意坐标点击、滑动、手势 |
| **执行Shell命令** | `Shizuku.newProcess()` | 截图、输入、获取系统信息 |
| **获取前台应用** | `dumpsys window` | 任务状态跟踪 |
| **截图** | `screencap -p` | Android 11以下的降级方案 |
| **文本输入** | `input text` / ADB Keyboard | ASCII字符输入 / 中文输入降级 |
| **系统按键** | `input keyevent` | 返回、Home等 |

### 最终结论

**✅ 推荐保留双权限方案**，但**无障碍服务现在可以覆盖95%的功能**，原因如下：

1. **无障碍服务能力升级**（Android 7.0+ GestureDescription API）
   - ✅ 坐标点击、滑动、长按、双击
   - ✅ 文本输入、截图、全局按键
   - ✅ UI元素操作
   - ⚠️ 唯一缺失：获取前台应用包名

2. **兼容性分析**
   | Android 版本 | 无障碍服务功能完整度 | 是否需要 Shizuku |
   |-------------|-------------------|----------------|
   | **Android 11+** | 100% | ❌ 不需要 |
   | **Android 7-10** | 95% (缺截图) | ⚠️ 可选（仅截图降级） |
   | **Android 6 及以下** | 60% (无坐标操作、无截图) | ✅ 强烈建议 |

3. **用户体验对比**
   - 无障碍服务：一次授权永久有效，速度快，稳定性好
   - Shizuku：重启后需重新激活，主要作为降级方案

4. **推荐配置策略**
   - **Android 11+**：仅启用无障碍服务即可
   - **Android 7-10**：无障碍服务为主，Shizuku 提供截图降级
   - **Android 6 及以下**：不推荐（功能受限严重）

---

## 🏗️ 核心架构设计

### 分层架构

```
┌─────────────────────────────────────────────────────┐
│                   Flutter UI 层                      │
│                  (Dart + Material)                   │
├─────────────────────────────────────────────────────┤
│                  业务逻辑层 (Dart)                   │
│  ┌──────────────┐ ┌──────────────┐ ┌─────────────┐  │
│  │ PhoneAgent   │ │ActionHandler │ │ModelClient  │  │
│  │   (核心)      │ │  (动作解析)   │ │  (AI对接)   │  │
│  └──────────────┘ └──────────────┘ └─────────────┘  │
├─────────────────────────────────────────────────────┤
│              Platform Channel (桥接层)               │
│         Flutter Dart ⟷ Android Kotlin              │
├─────────────────────────────────────────────────────┤
│              Android 原生层 (Kotlin)                 │
│  ┌──────────────────────────────────────────────┐  │
│  │        DeviceController (设备控制核心)         │  │
│  │  ┌─────────────┐       ┌──────────────────┐  │  │
│  │  │ Shizuku API │  ←→  │ Accessibility API │  │  │
│  │  │ (系统级控制) │       │   (应用级控制)     │  │  │
│  │  └─────────────┘       └──────────────────┘  │  │
│  └──────────────────────────────────────────────┘  │
├─────────────────────────────────────────────────────┤
│                  Android System                      │
│  InputManager │ WindowManager │ AccessibilityManager│
└─────────────────────────────────────────────────────┘
```

### 关键组件

#### 1. DeviceController (设备控制核心)

**职责**：封装所有设备控制操作，管理权限降级策略

**文件**：`android/app/src/main/kotlin/com/autoglm/auto_glm_mobile/DeviceController.kt`

**关键方法**：
```kotlin
class DeviceController(context: Context) {
    // 截图（降级策略：无障碍 → Shizuku）
    fun getScreenshot(timeout: Int, callback: (Bitmap?, Boolean) -> Unit)
    
    // 文本输入（降级策略：无障碍 → ADB Keyboard → input text）
    fun typeText(text: String, callback: (Boolean, String?) -> Unit)
    
    // 触摸操作（策略：Shizuku InputManager → Shell命令）
    fun tap(x: Int, y: Int, delay: Int, callback: (Boolean, String?) -> Unit)
    fun swipe(startX, startY, endX, endY, duration, delay, callback)
    fun longPress(x, y, duration, delay, callback)
    fun doubleTap(x, y, delay, callback)
    
    // 系统按键
    fun pressBack(delay: Int, callback: (Boolean, String?) -> Unit)
    fun pressHome(delay: Int, callback: (Boolean, String?) -> Unit)
    
    // 系统信息
    fun getCurrentApp(): String
}
```

#### 2. AutoGLMAccessibilityService (无障碍服务)

**职责**：提供无障碍API封装

**文件**：`android/app/src/main/kotlin/com/autoglm/auto_glm_mobile/AutoGLMAccessibilityService.kt`

**关键方法**：
```kotlin
class AutoGLMAccessibilityService : AccessibilityService() {
    companion object {
        fun isAvailable(): Boolean
        fun takeScreenshot(callback: (Bitmap?) -> Unit)
    }
    
    // 文本输入
    fun inputText(text: String): Boolean
    fun clearText(): Boolean
    
    // 全局操作
    fun performBack(): Boolean
    fun performHome(): Boolean
    fun performRecents(): Boolean
    
    // UI元素查找
    fun findNodesByText(text: String): List<AccessibilityNodeInfo>
    fun findNodeById(viewId: String): AccessibilityNodeInfo?
}
```

---

## 🔄 设备控制降级策略

### 1. 截图功能降级链

```
┌─────────────────────────────────────────────────┐
│ 优先级 1: 无障碍服务截图 (Android 11+)           │
│ ✅ 最可靠、最快速                                │
│ ✅ 支持所有应用（包括安全应用）                   │
│ ❌ 需要 Android 11+                             │
└─────────────────────────────────────────────────┘
              ↓ 降级
┌─────────────────────────────────────────────────┐
│ 优先级 2: Shizuku screencap (临时文件)           │
│ ✅ 支持 Android 9+                              │
│ ✅ 兼容性好                                      │
│ ❌ 速度较慢（需要写入文件）                       │
│ ❌ 部分安全应用可能屏蔽                          │
└─────────────────────────────────────────────────┘
```

**实现代码**（DeviceController.kt）：
```kotlin
fun getScreenshot(timeout: Int, callback: (Bitmap?, Boolean) -> Unit) {
    // 方法1: 无障碍服务（Android 11+）
    if (AutoGLMAccessibilityService.isAvailable()) {
        AutoGLMAccessibilityService.takeScreenshot { bitmap ->
            if (bitmap != null) {
                callback(bitmap, false)
                return@takeScreenshot
            }
            // 失败则继续降级
        }
    }
    
    // 方法2: Shizuku screencap
    if (Shizuku.pingBinder() && Shizuku.checkSelfPermission() == PERMISSION_GRANTED) {
        executeShizukuShellCommand("screencap -p /cache/screenshot.png")
        // 读取并返回bitmap
    }
}
```

### 2. 文本输入降级链

```
┌─────────────────────────────────────────────────┐
│ 优先级 1: 无障碍服务 ACTION_SET_TEXT             │
│ ✅ 完美支持中文                                  │
│ ✅ 最可靠                                        │
│ ✅ 支持所有输入框                                │
└─────────────────────────────────────────────────┘
              ↓ 降级
┌─────────────────────────────────────────────────┐
│ 优先级 2: Shizuku + ADB Keyboard                │
│ ✅ 支持中文                                      │
│ ❌ 需要额外安装 ADB Keyboard 应用                │
│ ❌ 需要切换输入法                                │
└─────────────────────────────────────────────────┘
              ↓ 降级
┌─────────────────────────────────────────────────┐
│ 优先级 3: Shizuku input text                    │
│ ✅ 无需额外安装                                  │
│ ❌ 仅支持 ASCII 字符                            │
│ ❌ 不支持中文                                    │
└─────────────────────────────────────────────────┘
```

**实现代码**（DeviceController.kt）：
```kotlin
fun typeText(text: String, callback: (Boolean, String?) -> Unit) {
    // 方法1: 无障碍服务
    if (AutoGLMAccessibilityService.isAvailable()) {
        val service = AutoGLMAccessibilityService.getInstance()
        if (service.inputText(text)) {
            callback(true, null)
            return
        }
    }
    
    // 方法2: ADB Keyboard (支持中文)
    if (tryAdbKeyboardInput(text)) {
        callback(true, null)
        return
    }
    
    // 方法3: input text (仅ASCII)
    if (text.all { it.code < 128 }) {
        executeShizukuShellCommand("input text \"$text\"")
        callback(true, null)
    } else {
        callback(false, "Chinese input requires ADB Keyboard")
    }
}
```

### 3. 触摸操作降级链

```
┌─────────────────────────────────────────────────┐
│ 优先级 1: 无障碍服务 GestureDescription         │
│ ✅ 最可靠、最稳定                                │
│ ✅ 一次授权永久有效                              │
│ ✅ 支持所有手势类型                              │
│ ✅ Android 7.0+                                 │
└─────────────────────────────────────────────────┘
              ↓ 降级
┌─────────────────────────────────────────────────┐
│ 优先级 2: Shizuku InputManager.injectInputEvent│
│ ✅ 精确控制                                      │
│ ✅ 速度快                                        │
│ ❌ 重启后需重新激活                              │
└─────────────────────────────────────────────────┘
              ↓ 降级
┌─────────────────────────────────────────────────┐
│ 优先级 3: Shizuku Shell 命令                    │
│ ✅ 兼容性最好                                    │
│ ❌ 速度较慢                                      │
│ ❌ 精度略低                                      │
└─────────────────────────────────────────────────┘
```

**实现代码**（DeviceController.kt）：
```kotlin
fun tap(x: Int, y: Int, delay: Int, callback: (Boolean, String?) -> Unit) {
    // 方法1: 无障碍服务手势 (Android 7.0+, 最可靠)
    if (AutoGLMAccessibilityService.isAvailable() && Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
        AutoGLMAccessibilityService.getInstance()?.performTap(x.toFloat(), y.toFloat()) { success ->
            if (success) {
                callback(true, null)
                return
            }
        }
    }
    
    // 方法2: Shizuku InputManager 注入事件
    try {
        injectTap(x.toFloat(), y.toFloat())
        callback(true, null)
    } catch (e: Exception) {
        // 方法3: Shell 命令降级
        executeShellCommand("input tap $x $y")
        callback(true, null)
    }
}
```

---

## 🔧 功能实现详解

### 1. 无障碍服务文本输入实现

**核心逻辑**（AutoGLMAccessibilityService.kt）：

```kotlin
fun inputText(text: String): Boolean {
    // 1. 获取当前窗口根节点
    val root = rootInActiveWindow ?: return false
    
    // 2. 找到最合适的可编辑节点
    val editableNode = findBestEditableNode(root)
    
    // 3. 尝试 ACTION_SET_TEXT
    if (trySetText(editableNode, text)) return true
    
    // 4. 尝试剪贴板粘贴
    if (tryClipboardPaste(editableNode, text)) return true
    
    return false
}

private fun findBestEditableNode(root: AccessibilityNodeInfo): AccessibilityNodeInfo? {
    // 优先级1: 查找输入焦点
    val inputFocus = root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
    if (inputFocus?.isEditable == true) return inputFocus
    
    // 优先级2: 查找可访问性焦点
    val a11yFocus = root.findFocus(AccessibilityNodeInfo.FOCUS_ACCESSIBILITY)
    if (a11yFocus?.isEditable == true) return a11yFocus
    
    // 优先级3: 遍历查找任意可编辑节点
    val editableNodes = mutableListOf<AccessibilityNodeInfo>()
    findEditableNodesRecursive(root, editableNodes)
    return editableNodes.sortedByDescending { it.isFocused }.firstOrNull()
}

private fun trySetText(node: AccessibilityNodeInfo, text: String): Boolean {
    // 确保节点获取焦点
    if (!node.isFocused) {
        node.performAction(AccessibilityNodeInfo.ACTION_FOCUS)
    }
    
    // 设置文本
    val arguments = Bundle()
    arguments.putCharSequence(ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text)
    return node.performAction(ACTION_SET_TEXT, arguments)
}
```

**优势**：
- ✅ 完美支持中文、Emoji等Unicode字符
- ✅ 自动查找焦点输入框
- ✅ 多种降级策略（ACTION_SET_TEXT → 剪贴板粘贴）

### 2. Shizuku Shell 命令执行实现

**核心逻辑**（DeviceController.kt）：

```kotlin
private fun executeShizukuShellCommand(command: String): String {
    // 检查 Shizuku 状态
    if (!Shizuku.pingBinder() || 
        Shizuku.checkSelfPermission() != PackageManager.PERMISSION_GRANTED) {
        return "Shizuku not available"
    }
    
    try {
        // 方法1: 反射调用 Shizuku.newProcess
        val shizukuClass = Class.forName("rikka.shizuku.Shizuku")
        val newProcessMethod = shizukuClass.getDeclaredMethod(
            "newProcess",
            Array<String>::class.java,
            Array<String>::class.java,
            String::class.java
        )
        val process = newProcessMethod.invoke(
            null, 
            arrayOf("sh", "-c", command), 
            null, 
            null
        ) as Process
        
        val output = process.inputStream.bufferedReader().readText()
        process.waitFor()
        return output
    } catch (e: Exception) {
        // 降级到 Runtime.exec
        val process = Runtime.getRuntime().exec(arrayOf("sh", "-c", command))
        return process.inputStream.bufferedReader().readText()
    }
}
```

### 3. ADB Keyboard 中文输入实现

**核心逻辑**（DeviceController.kt）：

```kotlin
private fun tryAdbKeyboardInput(text: String): Boolean {
    // 1. 检查 ADB Keyboard 是否安装
    val packageCheck = executeShizukuShellCommand("pm list packages com.android.adbkeyboard")
    if (!packageCheck.contains("com.android.adbkeyboard")) {
        return false
    }
    
    // 2. 切换到 ADB Keyboard
    val originalIme = executeShizukuShellCommand("settings get secure default_input_method")
    if (!originalIme.contains("com.android.adbkeyboard")) {
        executeShizukuShellCommand("ime set com.android.adbkeyboard/.AdbIME")
        Thread.sleep(500)
    }
    
    // 3. 清除现有文本
    executeShizukuShellCommand("am broadcast -a ADB_CLEAR_TEXT")
    Thread.sleep(200)
    
    // 4. Base64 编码并发送广播
    val encodedText = Base64.encodeToString(
        text.toByteArray(Charsets.UTF_8),
        Base64.NO_WRAP
    )
    val result = executeShizukuShellCommand("am broadcast -a ADB_INPUT_B64 --es msg $encodedText")
    
    // 5. 检查是否成功
    return result.contains("result=0") || result.contains("Broadcast completed")
}
```

**注意事项**：
- 需要用户安装 [ADB Keyboard](https://github.com/senzhk/ADBKeyBoard) 应用
- 会临时切换输入法（建议保持ADB Keyboard作为默认）
- 使用Base64编码避免特殊字符问题

---

## 🎯 最佳实践建议

### 1. 权限申请顺序

**推荐流程**：

```
┌─────────────────┐
│ 1. 无障碍服务     │ ← 优先引导用户开启
│   一次授权永久   │
└─────────────────┘
         ↓
┌─────────────────┐
│ 2. 悬浮窗权限    │ ← 显示任务状态
└─────────────────┘
         ↓
┌─────────────────┐
│ 3. Shizuku      │ ← 可选，提供增强功能
│   (高级用户)      │    和低版本兼容
└─────────────────┘
```

**理由**：
- 无障碍服务满足90%功能需求
- 用户体验最好（不需要ADB）
- Shizuku仅作为增强方案

### 2. Android 版本兼容策略

| Android 版本 | 推荐权限方案 | 功能完整度 |
|-------------|------------|-----------|
| **Android 11+** | 仅无障碍服务 | ⭐⭐⭐⭐⭐ 100% |
| **Android 9-10** | 无障碍 + Shizuku | ⭐⭐⭐⭐ 95% (截图需Shizuku) |
| **Android 9以下** | 不支持 | - |

### 3. 文本输入最佳实践

**中文输入推荐方案**：

1. **首选**：无障碍服务 `ACTION_SET_TEXT`
   - 完美支持、无需额外配置

2. **降级**：引导用户安装 ADB Keyboard
   ```kotlin
   if (text.contains(Regex("[\\u4e00-\\u9fa5]"))) {
       // 检测到中文
       if (!isAdbKeyboardInstalled()) {
           // 提示用户安装 ADB Keyboard
           showAdbKeyboardInstallDialog()
       }
   }
   ```

3. **兜底**：对于纯英文/数字，使用 `input text`

### 4. 错误处理建议

```kotlin
fun typeText(text: String, callback: (Boolean, String?) -> Unit) {
    try {
        // 尝试无障碍服务
        if (tryAccessibilityInput(text)) {
            callback(true, null)
            return
        }
    } catch (e: Exception) {
        Log.e("DeviceController", "Accessibility input failed", e)
    }
    
    try {
        // 降级到 Shizuku
        if (tryShizukuInput(text)) {
            callback(true, null)
            return
        }
    } catch (e: Exception) {
        Log.e("DeviceController", "Shizuku input failed", e)
    }
    
    // 所有方法都失败
    callback(false, "All input methods failed. Please check permissions.")
}
```

### 5. 用户引导建议

**首次启动流程**：

```
┌────────────────────────────────────┐
│ 1. 欢迎页面                         │
│    - 介绍应用功能                   │
│    - 说明权限必要性                 │
└────────────────────────────────────┘
         ↓
┌────────────────────────────────────┐
│ 2. 无障碍服务引导                   │
│    - 图文教程                       │
│    - 一键跳转设置页面               │
│    - 自动检测是否已授权             │
└────────────────────────────────────┘
         ↓
┌────────────────────────────────────┐
│ 3. Shizuku 可选引导 (Android 9-10)  │
│    - 说明为降级方案                 │
│    - 提供详细激活步骤               │
│    - 允许跳过（仅Android 11+）      │
└────────────────────────────────────┘
         ↓
┌────────────────────────────────────┐
│ 4. 功能测试                         │
│    - 测试截图                       │
│    - 测试文本输入                   │
│    - 测试触摸操作                   │
└────────────────────────────────────┘
```

---

## 📊 性能优化建议

### 1. 截图优化

```kotlin
// 缓存屏幕尺寸，避免重复查询
private var cachedScreenSize: Pair<Int, Int>? = null

fun getScreenshot(callback: (Bitmap?) -> Unit) {
    // 使用异步执行器
    executor.execute {
        // 优先使用无障碍服务（最快）
        if (AutoGLMAccessibilityService.isAvailable()) {
            // Android 11+ 截图速度约 50-100ms
            takeScreenshotViaAccessibility(callback)
        } else {
            // Shizuku screencap 速度约 200-500ms
            takeScreenshotViaShizuku(callback)
        }
    }
}
```

### 2. 文本输入优化

```kotlin
// 批量输入优化
fun typeTextBatch(texts: List<String>, callback: (Boolean) -> Unit) {
    executor.execute {
        val service = AutoGLMAccessibilityService.getInstance()
        if (service != null) {
            // 一次性查找输入框，避免重复遍历
            val editableNode = findBestEditableNode()
            for (text in texts) {
                trySetText(editableNode, text)
                Thread.sleep(100) // 避免输入过快
            }
            callback(true)
        }
    }
}
```

### 3. 触摸操作优化

```kotlin
// 复用 MotionEvent 对象
private val motionEventPool = Pools.SimplePool<MotionEvent>(10)

fun tap(x: Float, y: Float) {
    val event = motionEventPool.acquire() ?: MotionEvent.obtain(...)
    try {
        injectInputEvent(event)
    } finally {
        motionEventPool.release(event)
    }
}
```

---

## 🔍 调试技巧

### 1. 查看无障碍服务日志

```bash
adb logcat -s Accessibility:D
```

### 2. 查看 Shizuku 状态

```bash
adb shell dumpsys activity service rikka.shizuku
```

### 3. 测试文本输入

```bash
# 测试 ADB Keyboard
adb shell am broadcast -a ADB_INPUT_B64 --es msg "$(echo -n '测试' | base64)"

# 测试 input text
adb shell input text "test"
```

### 4. 检查输入法

```bash
# 查看当前输入法
adb shell settings get secure default_input_method

# 切换输入法
adb shell ime set com.android.adbkeyboard/.AdbIME
```

---

## 📚 参考资料

### Android 官方文档
- [AccessibilityService](https://developer.android.com/reference/android/accessibilityservice/AccessibilityService)
- [takeScreenshot()](https://developer.android.com/reference/android/accessibilityservice/AccessibilityService#takeScreenshot(int,%20java.util.concurrent.Executor,%20android.accessibilityservice.AccessibilityService.TakeScreenshotCallback))
- [InputManager](https://developer.android.com/reference/android/hardware/input/InputManager)

### 第三方工具
- [Shizuku](https://shizuku.rikka.app/)
- [ADB Keyboard](https://github.com/senzhk/ADBKeyBoard)

### 相关项目
- [Open-AutoGLM](https://github.com/THUDM/AutoGLM) - Python 版原项目
