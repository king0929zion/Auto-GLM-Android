package com.autoglm.auto_glm_mobile

import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.Image
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.SystemClock
import android.util.DisplayMetrics
import android.view.InputDevice
import android.view.KeyCharacterMap
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.WindowManager
import rikka.shizuku.Shizuku
import rikka.shizuku.ShizukuBinderWrapper
import rikka.shizuku.SystemServiceHelper
import java.lang.reflect.Method
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * 设备控制器
 * 通过Shizuku API实现设备控制功能，替代ADB
 */
class DeviceController(private val context: Context) {
    
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private val handlerThread = HandlerThread("DeviceControllerThread")
    private val handler: Handler
    private val mainHandler = Handler(android.os.Looper.getMainLooper())
    
    private var screenWidth: Int = 1080
    private var screenHeight: Int = 2400
    private var screenDensity: Float = 2.0f
    
    // InputManager 反射
    private var inputManager: Any? = null
    private var injectInputEventMethod: Method? = null
    
    init {
        handlerThread.start()
        handler = Handler(handlerThread.looper)
        
        initDisplayMetrics()
        initInputManager()
    }
    
    /**
     * 初始化屏幕参数
     */
    private fun initDisplayMetrics() {
        val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val display = windowManager.defaultDisplay
        val metrics = DisplayMetrics()
        display.getRealMetrics(metrics)
        
        screenWidth = metrics.widthPixels
        screenHeight = metrics.heightPixels
        screenDensity = metrics.density
    }
    
    /**
     * 初始化InputManager用于注入输入事件
     */
    private fun initInputManager() {
        try {
            if (!Shizuku.pingBinder() || 
                Shizuku.checkSelfPermission() != PackageManager.PERMISSION_GRANTED) {
                return
            }
            
            // 通过Shizuku获取InputManager服务
            val inputManagerClass = Class.forName("android.hardware.input.InputManager")
            val getInstanceMethod = inputManagerClass.getMethod("getInstance")
            inputManager = getInstanceMethod.invoke(null)
            
            // 获取injectInputEvent方法
            injectInputEventMethod = inputManagerClass.getMethod(
                "injectInputEvent",
                android.view.InputEvent::class.java,
                Int::class.javaPrimitiveType
            )
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
    
    /**
     * 获取屏幕截图
     * 优先级：1. 无障碍服务 2. Shizuku shell命令
     */
    fun getScreenshot(timeout: Int, callback: (Bitmap?, Boolean) -> Unit) {
        executor.execute {
            try {
                android.util.Log.d("DeviceController", "Starting screenshot capture...")
                
                // 方法1: 使用无障碍服务截图 (最可靠，Android 11+)
                if (AutoGLMAccessibilityService.isAvailable()) {
                    android.util.Log.d("DeviceController", "Trying Accessibility Service screenshot...")
                    
                    val latch = java.util.concurrent.CountDownLatch(1)
                    var resultBitmap: Bitmap? = null
                    
                    handler.post {
                        AutoGLMAccessibilityService.takeScreenshot { bitmap ->
                            resultBitmap = bitmap
                            latch.countDown()
                        }
                    }
                    
                    // 等待截图完成，最多5秒
                    if (latch.await(5, java.util.concurrent.TimeUnit.SECONDS) && resultBitmap != null) {
                        android.util.Log.d("DeviceController", "Accessibility screenshot success: ${resultBitmap!!.width}x${resultBitmap!!.height}")
                        callback(resultBitmap, false)
                        return@execute
                    }
                    android.util.Log.w("DeviceController", "Accessibility screenshot failed or timed out")
                } else {
                    android.util.Log.d("DeviceController", "Accessibility Service not available")
                }
                
                // 方法2: 使用Shizuku screencap命令
                android.util.Log.d("DeviceController", "Trying Shizuku screenshot...")
                
                if (!Shizuku.pingBinder()) {
                    android.util.Log.e("DeviceController", "Shizuku binder not available")
                    callback(null, false)
                    return@execute
                }
                
                if (Shizuku.checkSelfPermission() != PackageManager.PERMISSION_GRANTED) {
                    android.util.Log.e("DeviceController", "Shizuku permission not granted")
                    callback(null, false)
                    return@execute
                }
                
                // 使用应用私有目录
                val tempFile = context.cacheDir.absolutePath + "/screenshot.png"
                val shResult = executeShizukuShellCommand("screencap -p $tempFile")
                android.util.Log.d("DeviceController", "screencap result: $shResult")
                
                val file = java.io.File(tempFile)
                if (file.exists() && file.length() > 0) {
                    val bitmap = android.graphics.BitmapFactory.decodeFile(tempFile)
                    file.delete()
                    
                    if (bitmap != null) {
                        android.util.Log.d("DeviceController", "Shizuku screenshot success: ${bitmap.width}x${bitmap.height}")
                        callback(bitmap, false)
                        return@execute
                    }
                }
                
                // 尝试/sdcard目录
                val sdcardFile = "/sdcard/autoglm_screenshot.png"
                val sdResult = executeShizukuShellCommand("screencap -p $sdcardFile")
                
                val sdFile = java.io.File(sdcardFile)
                if (sdFile.exists() && sdFile.length() > 0) {
                    val bitmap = android.graphics.BitmapFactory.decodeFile(sdcardFile)
                    sdFile.delete()
                    
                    if (bitmap != null) {
                        android.util.Log.d("DeviceController", "Shizuku screenshot (sdcard) success")
                        callback(bitmap, false)
                        return@execute
                    }
                }
                
                android.util.Log.e("DeviceController", "All screenshot methods failed")
                callback(null, false)
                
            } catch (e: Exception) {
                android.util.Log.e("DeviceController", "Screenshot error: ${e.message}", e)
                val isSensitive = e.message?.contains("secure") == true
                callback(null, isSensitive)
            }
        }
    }
    
    /**
     * 通过Shizuku执行shell命令
     * 使用反射调用Shizuku的内部方法
     */
    private fun executeShizukuShellCommand(command: String): String {
        return try {
            if (!Shizuku.pingBinder() || 
                Shizuku.checkSelfPermission() != PackageManager.PERMISSION_GRANTED) {
                return "Shizuku not available"
            }
            
            android.util.Log.d("DeviceController", "Executing via Shizuku: $command")
            
            // 方法1: 尝试通过反射调用Shizuku.newProcess
            try {
                val shizukuClass = Class.forName("rikka.shizuku.Shizuku")
                val newProcessMethod = shizukuClass.getDeclaredMethod(
                    "newProcess",
                    Array<String>::class.java,
                    Array<String>::class.java,
                    String::class.java
                )
                newProcessMethod.isAccessible = true
                
                val process = newProcessMethod.invoke(null, arrayOf("sh", "-c", command), null, null) as Process
                val output = process.inputStream.bufferedReader().readText()
                val error = process.errorStream.bufferedReader().readText()
                val exitCode = process.waitFor()
                
                android.util.Log.d("DeviceController", "Shizuku shell exit: $exitCode, out: $output, err: $error")
                
                return if (exitCode == 0) output else "Error: $error (exit $exitCode)"
            } catch (e: Exception) {
                android.util.Log.w("DeviceController", "Shizuku.newProcess failed: ${e.message}")
            }
            
            // 方法2: 使用ShizukuRemoteProcess直接构造
            try {
                val remoteProcessClass = Class.forName("rikka.shizuku.ShizukuRemoteProcess")
                val constructor = remoteProcessClass.getDeclaredConstructor(
                    Array<String>::class.java,
                    Array<String>::class.java,
                    String::class.java
                )
                constructor.isAccessible = true
                
                val process = constructor.newInstance(arrayOf("sh", "-c", command), null, null) as Process
                val output = process.inputStream.bufferedReader().readText()
                val error = process.errorStream.bufferedReader().readText()
                val exitCode = process.waitFor()
                
                android.util.Log.d("DeviceController", "RemoteProcess exit: $exitCode")
                return if (exitCode == 0) output else "Error: $error (exit $exitCode)"
            } catch (e: Exception) {
                android.util.Log.w("DeviceController", "ShizukuRemoteProcess failed: ${e.message}")
            }
            
            // 方法3: 降级使用普通Runtime.exec（可能无权限）
            android.util.Log.d("DeviceController", "Falling back to Runtime.exec")
            val process = Runtime.getRuntime().exec(arrayOf("sh", "-c", command))
            val output = process.inputStream.bufferedReader().readText()
            val error = process.errorStream.bufferedReader().readText()
            val exitCode = process.waitFor()
            
            android.util.Log.d("DeviceController", "Runtime.exec exit: $exitCode")
            if (exitCode == 0) output else "Error: $error (exit $exitCode)"
            
        } catch (e: Exception) {
            android.util.Log.e("DeviceController", "Shell command error: ${e.message}")
            "Exception: ${e.message}"
        }
    }
    
    /**
     * 获取当前前台应用
     * 使用 dumpsys window 命令（与原Python项目一致）
     */
    fun getCurrentApp(): String {
        return try {
            // 使用Shizuku执行dumpsys window
            val output = executeShizukuShellCommand("dumpsys window")
            
            android.util.Log.d("DeviceController", "Getting current app...")
            
            // 解析窗口焦点信息
            for (line in output.split("\n")) {
                if (line.contains("mCurrentFocus") || line.contains("mFocusedApp")) {
                    // 查找已知应用包名
                    for ((appName, packageName) in APP_PACKAGES) {
                        if (line.contains(packageName)) {
                            android.util.Log.d("DeviceController", "Current app: $appName")
                            return appName
                        }
                    }
                }
            }
            
            "System Home"
        } catch (e: Exception) {
            android.util.Log.e("DeviceController", "Error getting current app: ${e.message}")
            "System Home"
        }
    }
    
    /**
     * 从包名获取应用名称
     */
    private fun getAppNameFromPackage(packageName: String): String? {
        // 先从APP_PACKAGES中查找
        for ((appName, pkg) in APP_PACKAGES) {
            if (pkg == packageName) {
                return appName
            }
        }
        // 否则从系统获取
        return try {
            val pm = context.packageManager
            val appInfo = pm.getApplicationInfo(packageName, 0)
            pm.getApplicationLabel(appInfo).toString()
        } catch (e: Exception) {
            null
        }
    }
    
    companion object {
        /**
         * 应用名称到包名的映射（复刻原Python项目的apps.py）
         */
        val APP_PACKAGES = mapOf(
            // 社交通讯
            "微信" to "com.tencent.mm",
            "QQ" to "com.tencent.mobileqq",
            "微博" to "com.sina.weibo",
            // 电商购物
            "淘宝" to "com.taobao.taobao",
            "京东" to "com.jingdong.app.mall",
            "拼多多" to "com.xunmeng.pinduoduo",
            // 生活服务
            "小红书" to "com.xingin.xhs",
            "豆瓣" to "com.douban.frodo",
            "知乎" to "com.zhihu.android",
            // 地图导航
            "高德地图" to "com.autonavi.minimap",
            "百度地图" to "com.baidu.BaiduMap",
            // 外卖美食
            "美团" to "com.sankuai.meituan",
            "大众点评" to "com.dianping.v1",
            "饿了么" to "me.ele",
            "肯德基" to "com.yek.android.kfc.activitys",
            // 出行旅游
            "携程" to "ctrip.android.view",
            "铁路12306" to "com.MobileTicket",
            "12306" to "com.MobileTicket",
            "去哪儿" to "com.Qunar",
            "滴滴出行" to "com.sdu.did.psnger",
            // 视频娱乐
            "bilibili" to "tv.danmaku.bili",
            "抖音" to "com.ss.android.ugc.aweme",
            "快手" to "com.smile.gifmaker",
            "腾讯视频" to "com.tencent.qqlive",
            "爱奇艺" to "com.qiyi.video",
            "优酷视频" to "com.youku.phone",
            // 音乐
            "网易云音乐" to "com.netease.cloudmusic",
            "QQ音乐" to "com.tencent.qqmusic",
            // 办公
            "飞书" to "com.ss.android.lark",
            "QQ邮箱" to "com.tencent.androidqqmail",
            // 系统
            "Settings" to "com.android.settings",
            "设置" to "com.android.settings",
            "Chrome" to "com.android.chrome",
            "浏览器" to "com.android.browser"
        )
    }
    
    /**
     * 点击操作
     */
    fun tap(x: Int, y: Int, delay: Int, displayId: Int = -1, callback: (Boolean, String?) -> Unit) {
        // Show visual feedback only if on default display
        if (displayId == -1 || displayId == 0) {
            mainHandler.post {
                FloatingWindowService.showTouchFeedback(x, y)
            }
        }

        executor.execute {
            // For virtual display, use shell command directly as injectInputEvent might target default display
            if (displayId != -1 && displayId != 0) {
                 try {
                    executeShellCommand("input -d $displayId tap $x $y")
                    Thread.sleep(delay.toLong())
                    callback(true, null)
                } catch (e: Exception) {
                    callback(false, e.message)
                }
                return@execute
            }

            try {
                injectTap(x.toFloat(), y.toFloat())
                Thread.sleep(delay.toLong())
                callback(true, null)
            } catch (e: Exception) {
                // 降级方案：使用shell命令
                try {
                    executeShellCommand("input tap $x $y")
                    Thread.sleep(delay.toLong())
                    callback(true, null)
                } catch (e2: Exception) {
                    callback(false, e2.message)
                }
            }
        }
    }
    
    /**
     * 双击操作
     */
    fun doubleTap(x: Int, y: Int, delay: Int, displayId: Int = -1, callback: (Boolean, String?) -> Unit) {
        // Show visual feedback
        if (displayId == -1 || displayId == 0) {
            mainHandler.post {
                FloatingWindowService.showTouchFeedback(x, y)
            }
        }

        executor.execute {
             if (displayId != -1 && displayId != 0) {
                 try {
                    executeShellCommand("input -d $displayId tap $x $y")
                    Thread.sleep(100)
                    executeShellCommand("input -d $displayId tap $x $y")
                    Thread.sleep(delay.toLong())
                    callback(true, null)
                } catch (e: Exception) {
                    callback(false, e.message)
                }
                return@execute
            }

            try {
                injectTap(x.toFloat(), y.toFloat())
                Thread.sleep(100) // 间隔
                injectTap(x.toFloat(), y.toFloat())
                Thread.sleep(delay.toLong())
                callback(true, null)
            } catch (e: Exception) {
                try {
                    executeShellCommand("input tap $x $y")
                    Thread.sleep(100)
                    executeShellCommand("input tap $x $y")
                    Thread.sleep(delay.toLong())
                    callback(true, null)
                } catch (e2: Exception) {
                    callback(false, e2.message)
                }
            }
        }
    }
    
    /**
     * 长按操作
     */
    fun longPress(x: Int, y: Int, duration: Int, delay: Int, displayId: Int = -1, callback: (Boolean, String?) -> Unit) {
        // Show visual feedback
        if (displayId == -1 || displayId == 0) {
            mainHandler.post {
                FloatingWindowService.showTouchFeedback(x, y)
            }
        }

        executor.execute {
            if (displayId != -1 && displayId != 0) {
                 try {
                    executeShellCommand("input -d $displayId swipe $x $y $x $y $duration")
                    Thread.sleep(delay.toLong())
                    callback(true, null)
                } catch (e: Exception) {
                    callback(false, e.message)
                }
                return@execute
            }

            try {
                // 使用swipe模拟长按
                injectSwipe(x.toFloat(), y.toFloat(), x.toFloat(), y.toFloat(), duration.toLong())
                Thread.sleep(delay.toLong())
                callback(true, null)
            } catch (e: Exception) {
                try {
                    executeShellCommand("input swipe $x $y $x $y $duration")
                    Thread.sleep(delay.toLong())
                    callback(true, null)
                } catch (e2: Exception) {
                    callback(false, e2.message)
                }
            }
        }
    }
    
    /**
     * 滑动操作
     */
    fun swipe(startX: Int, startY: Int, endX: Int, endY: Int, 
              duration: Int, delay: Int, displayId: Int = -1, callback: (Boolean, String?) -> Unit) {
        // Visual feedback (disabled - method not implemented)
        // if (displayId == -1 || displayId == 0) {
        //     mainHandler.post {
        //         FloatingWindowService.showSwipeFeedback(startX, startY, endX, endY)
        //     }
        // }

        executor.execute {
            if (displayId != -1 && displayId != 0) {
                 try {
                    executeShellCommand("input -d $displayId swipe $startX $startY $endX $endY $duration")
                    Thread.sleep(delay.toLong())
                    callback(true, null)
                } catch (e: Exception) {
                    callback(false, e.message)
                }
                return@execute
            }

            try {
                injectSwipe(
                    startX.toFloat(), startY.toFloat(),
                    endX.toFloat(), endY.toFloat(),
                    duration.toLong()
                )
                Thread.sleep(delay.toLong())
                callback(true, null)
            } catch (e: Exception) {
                try {
                    executeShellCommand("input swipe $startX $startY $endX $endY $duration")
                    Thread.sleep(delay.toLong())
                    callback(true, null)
                } catch (e2: Exception) {
                    callback(false, e2.message)
                }
            }
        }
    }
    /**
     * 输入文本
     * 策略：
     * 1. Shizuku 已授权 -> ADB Keyboard / input text / 剪贴板
     * 2. Shizuku 未授权 -> 无障碍服务
     */
    /**
     * 输入文本
     * 策略：
     * 1. Shizuku 已授权 -> ADB Keyboard / input text / 剪贴板
     * 2. Shizuku 未授权 -> 无障碍服务
     */
    fun typeText(text: String, displayId: Int = -1, callback: (Boolean, String?) -> Unit) {
        executor.execute {
            try {
                android.util.Log.d("DeviceController", "typeText: $text, displayId: $displayId")
                
                // 检查 Shizuku 是否可用
                val shizukuAvailable = try {
                    Shizuku.pingBinder() && Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED
                } catch (e: Exception) {
                    false
                }
                
                if (shizukuAvailable) {
                    android.util.Log.d("DeviceController", "Shizuku available, trying shell methods")
                    
                    // ADB Keyboard method disabled - method not implemented
                    // if (displayId == -1 || displayId == 0) {
                    //     val adbKeyboardResult = tryAdbKeyboardInput(text)
                    //     if (adbKeyboardResult) {
                    //         android.util.Log.d("DeviceController", "ADB Keyboard input success")
                    //         callback(true, null)
                    //         return@execute
                    //     }
                    // }
                    
                    // 方法2: 使用input text命令 (仅支持ASCII)
                    val inputTextResult = tryInputTextCommand(text, displayId)
                    if (inputTextResult) {
                        android.util.Log.d("DeviceController", "input text command success")
                        callback(true, null)
                        return@execute
                    }
                    
                    // 方法3: 使用剪贴板 + 模拟粘贴
                    val clipboardResult = tryClipboardPaste(text, displayId)
                    if (clipboardResult) {
                        android.util.Log.d("DeviceController", "clipboard paste success")
                        callback(true, null)
                        return@execute
                    }
                    
                    android.util.Log.w("DeviceController", "Shizuku methods failed, falling back to accessibility")
                }
                
                // 虚拟屏幕无法使用无障碍服务输入
                if (displayId != -1 && displayId != 0) {
                     callback(false, "虚拟屏幕输入失败: Shizuku input methods failed")
                     return@execute
                }
                
                // 回退：使用无障碍服务
                android.util.Log.d("DeviceController", "Using accessibility service for input")
                
                if (!AutoGLMAccessibilityService.isEnabled(context)) {
                    android.util.Log.e("DeviceController", "Accessibility Service not enabled")
                    callback(false, "无障碍服务未启用")
                    return@execute
                }
                
                val service = AutoGLMAccessibilityService.waitForInstance(2000)
                if (service == null) {
                    android.util.Log.e("DeviceController", "Accessibility Service instance is null")
                    callback(false, "无障碍服务正在连接，请稍后重试")
                    return@execute
                }
                
                // 尝试最多3次
                for (attempt in 1..3) {
                    android.util.Log.d("DeviceController", "Accessibility attempt $attempt/3")
                    
                    val latch = java.util.concurrent.CountDownLatch(1)
                    var accessibilityResult = false
                     
                    mainHandler.post {
                        accessibilityResult = service.typeTextLikePython(text)
                        android.util.Log.d("DeviceController", "Accessibility input result: $accessibilityResult")
                        latch.countDown()
                    }
                    
                    latch.await(5, java.util.concurrent.TimeUnit.SECONDS)
                    
                    if (accessibilityResult) {
                        callback(true, null)
                        return@execute
                    }
                    
                    if (attempt < 3) {
                        android.util.Log.w("DeviceController", "Attempt $attempt failed, waiting before retry...")
                        Thread.sleep(500)
                    }
                }
                
                android.util.Log.e("DeviceController", "All input methods failed")
                val reason = AutoGLMAccessibilityService.getLastInputFailure()
                callback(false, reason ?: "文本输入失败，请确保输入框已获取焦点")
                
            } catch (e: Exception) {
                android.util.Log.e("DeviceController", "typeText error: ${e.message}", e)
                callback(false, e.message)
            }
        }
    }
    
    // ... tryAdbKeyboardInput (unchanged, as it's only for default display) ...

    /**
     * 使用input text命令输入
     */
    private fun tryInputTextCommand(text: String, displayId: Int = -1): Boolean {
        return try {
            // 转义特殊字符
            val escapedText = text
                .replace("\\", "\\\\")
                .replace("\"", "\\\"")
                .replace("'", "\\'")
                .replace(" ", "%s")
                .replace("&", "\\&")
                .replace("|", "\\|")
                .replace("<", "\\<")
                .replace(">", "\\>")
                .replace("(", "\\(")
                .replace(")", "\\)")
                .replace(";", "\\;")
            
            val displayArg = if (displayId != -1) "-d $displayId " else ""
            val result = executeShellCommand("input ${displayArg}text \"$escapedText\"")
            android.util.Log.d("DeviceController", "input text result: $result")
            Thread.sleep(300)
            
            true
        } catch (e: Exception) {
            android.util.Log.e("DeviceController", "input text error: ${e.message}")
            false
        }
    }
    
    /**
     * 使用剪贴板粘贴
     */
    private fun tryClipboardPaste(text: String, displayId: Int = -1): Boolean {
        return try {
            // 设置剪贴板内容
            val encodedText = android.util.Base64.encodeToString(
                text.toByteArray(Charsets.UTF_8),
                android.util.Base64.NO_WRAP
            )
            
            // 使用服务设置剪贴板 (Global clipboard)
            // Note: Clipboard is global, so no displayId needed here usually
            executeShellCommand("service call clipboard 2 i32 1 s16 '$text'")
            Thread.sleep(200)
            
            // 模拟Ctrl+V粘贴 (targets specific display)
            val displayArg = if (displayId != -1) "-d $displayId " else ""
            executeShellCommand("input ${displayArg}keyevent 279") // KEYCODE_PASTE
            Thread.sleep(300)
            
            true
        } catch (e: Exception) {
            android.util.Log.e("DeviceController", "clipboard paste error: ${e.message}")
            false
        }
    }
    
    /**
     * 清除文本
     */
    fun clearText(displayId: Int = -1, callback: (Boolean, String?) -> Unit) {
        executor.execute {
            try {
                if (displayId != -1 && displayId != 0) {
                     // Virtual display: use CLEAR key event
                     executeShellCommand("input -d $displayId keyevent 28") // KEYCODE_CLEAR? No, usually not mapped. 
                     // Operit uses KEYCODE_CLEAR (which is 28? No, 28 is CLEAR in KeyEvent but typically it's DEL for backspace or other)
                     // Actually Operit code says KEYCODE_CLEAR. Let's check constant.
                     // KeyEvent.KEYCODE_CLEAR is 28.
                     // But often used is KEYCODE_DEL (67) or long press DEL.
                     // Operit uses KEYCODE_CLEAR. I will follow.
                     executeShellCommand("input -d $displayId keyevent 28")
                     Thread.sleep(300)
                     callback(true, null)
                } else {
                    executeShellCommand("am broadcast -a ADB_CLEAR_TEXT")
                    Thread.sleep(300)
                    callback(true, null)
                }
            } catch (e: Exception) {
                callback(false, e.message)
            }
        }
    }
    
    /**
     * 按返回键
     */
    fun pressBack(delay: Int, displayId: Int = -1, callback: (Boolean, String?) -> Unit) {
        executor.execute {
            if (displayId != -1 && displayId != 0) {
                 try {
                    executeShellCommand("input -d $displayId keyevent 4")
                    Thread.sleep(delay.toLong())
                    callback(true, null)
                } catch (e: Exception) {
                    callback(false, e.message)
                }
                return@execute
            }

            try {
                injectKeyEvent(KeyEvent.KEYCODE_BACK)
                Thread.sleep(delay.toLong())
                callback(true, null)
            } catch (e: Exception) {
                try {
                    executeShellCommand("input keyevent 4")
                    Thread.sleep(delay.toLong())
                    callback(true, null)
                } catch (e2: Exception) {
                    callback(false, e2.message)
                }
            }
        }
    }
    
    /**
     * 按Home键
     */
    fun pressHome(delay: Int, displayId: Int = -1, callback: (Boolean, String?) -> Unit) {
        executor.execute {
            if (displayId != -1 && displayId != 0) {
                 try {
                    executeShellCommand("input -d $displayId keyevent 3")
                    Thread.sleep(delay.toLong())
                    callback(true, null)
                } catch (e: Exception) {
                    callback(false, e.message)
                }
                return@execute
            }

            try {
                injectKeyEvent(KeyEvent.KEYCODE_HOME)
                Thread.sleep(delay.toLong())
                callback(true, null)
            } catch (e: Exception) {
                try {
                    executeShellCommand("input keyevent KEYCODE_HOME")
                    Thread.sleep(delay.toLong())
                    callback(true, null)
                } catch (e2: Exception) {
                    callback(false, e2.message)
                }
            }
        }
    }
    
    /**
     * 注入触摸事件
     */
    private fun injectTap(x: Float, y: Float) {
        val downTime = SystemClock.uptimeMillis()
        
        val downEvent = MotionEvent.obtain(
            downTime, downTime,
            MotionEvent.ACTION_DOWN,
            x, y, 0
        )
        downEvent.source = InputDevice.SOURCE_TOUCHSCREEN
        
        val upEvent = MotionEvent.obtain(
            downTime, downTime + 50,
            MotionEvent.ACTION_UP,
            x, y, 0
        )
        upEvent.source = InputDevice.SOURCE_TOUCHSCREEN
        
        injectInputEvent(downEvent)
        Thread.sleep(50)
        injectInputEvent(upEvent)
        
        downEvent.recycle()
        upEvent.recycle()
    }
    
    /**
     * 注入滑动事件
     */
    private fun injectSwipe(startX: Float, startY: Float, 
                            endX: Float, endY: Float, duration: Long) {
        val steps = (duration / 10).toInt().coerceAtLeast(10)
        val deltaX = (endX - startX) / steps
        val deltaY = (endY - startY) / steps
        val stepDuration = duration / steps
        
        val downTime = SystemClock.uptimeMillis()
        var currentX = startX
        var currentY = startY
        
        // DOWN事件
        val downEvent = MotionEvent.obtain(
            downTime, downTime,
            MotionEvent.ACTION_DOWN,
            currentX, currentY, 0
        )
        downEvent.source = InputDevice.SOURCE_TOUCHSCREEN
        injectInputEvent(downEvent)
        downEvent.recycle()
        
        // MOVE事件
        for (i in 1 until steps) {
            currentX += deltaX
            currentY += deltaY
            Thread.sleep(stepDuration)
            
            val moveEvent = MotionEvent.obtain(
                downTime, SystemClock.uptimeMillis(),
                MotionEvent.ACTION_MOVE,
                currentX, currentY, 0
            )
            moveEvent.source = InputDevice.SOURCE_TOUCHSCREEN
            injectInputEvent(moveEvent)
            moveEvent.recycle()
        }
        
        // UP事件
        val upEvent = MotionEvent.obtain(
            downTime, SystemClock.uptimeMillis(),
            MotionEvent.ACTION_UP,
            endX, endY, 0
        )
        upEvent.source = InputDevice.SOURCE_TOUCHSCREEN
        injectInputEvent(upEvent)
        upEvent.recycle()
    }
    
    /**
     * 注入按键事件
     */
    private fun injectKeyEvent(keyCode: Int) {
        val downTime = SystemClock.uptimeMillis()
        
        val downEvent = KeyEvent(
            downTime, downTime,
            KeyEvent.ACTION_DOWN,
            keyCode, 0
        )
        
        val upEvent = KeyEvent(
            downTime, downTime + 50,
            KeyEvent.ACTION_UP,
            keyCode, 0
        )
        
        injectInputEvent(downEvent)
        Thread.sleep(50)
        injectInputEvent(upEvent)
    }
    
    /**
     * 注入输入事件到系统
     */
    private fun injectInputEvent(event: android.view.InputEvent) {
        try {
            if (inputManager != null && injectInputEventMethod != null) {
                // 使用INJECT_INPUT_EVENT_MODE_ASYNC = 0
                injectInputEventMethod?.invoke(inputManager, event, 0)
            } else {
                throw Exception("InputManager not initialized")
            }
        } catch (e: Exception) {
            throw e
        }
    }
    
    /**
     * 执行Shell命令（使用Shizuku权限）
     */
    private fun executeShellCommand(command: String): String {
        return executeShizukuShellCommand(command)
    }
    
    /**
     * 释放资源
     */
    fun release() {
        executor.shutdown()
        handlerThread.quitSafely()
    }
}
