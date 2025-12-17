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
import android.os.Looper
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
    private val mainHandler = Handler(Looper.getMainLooper())
    
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
                if (AutoGLMAccessibilityService.isEnabled(context)) {
                    AutoGLMAccessibilityService.waitForInstance(1200)
                }
                if (AutoGLMAccessibilityService.isAvailable()) {
                    android.util.Log.d("DeviceController", "Trying Accessibility Service screenshot...")
                    
                    val latch = java.util.concurrent.CountDownLatch(1)
                    var resultBitmap: Bitmap? = null
                    
                    mainHandler.post {
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
     * 降级策略：无障碍服务 → Shizuku InputManager → Shell命令
     */
    fun tap(x: Int, y: Int, delay: Int, callback: (Boolean, String?) -> Unit) {
        executor.execute {
            try {
                // 方法1: 无障碍服务手势 (Android 7.0+, 最可靠)
                val a11yServiceForGesture =
                    if (AutoGLMAccessibilityService.isEnabled(context)) AutoGLMAccessibilityService.waitForInstance(1200) else null
                if (a11yServiceForGesture != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    android.util.Log.d("DeviceController", "Trying Accessibility gesture tap...")
                     
                    val latch = java.util.concurrent.CountDownLatch(1)
                    var gestureSuccess = false
                     
                    mainHandler.post {
                        a11yServiceForGesture.performTap(x.toFloat(), y.toFloat()) { success ->
                            gestureSuccess = success
                            latch.countDown()
                        }
                    }
                    
                    if (latch.await(3, java.util.concurrent.TimeUnit.SECONDS) && gestureSuccess) {
                        Thread.sleep(delay.toLong())
                        callback(true, null)
                        return@execute
                    }
                    android.util.Log.w("DeviceController", "Accessibility gesture failed, trying Shizuku...")
                }
                
                // 方法2: Shizuku InputManager 注入事件
                injectTap(x.toFloat(), y.toFloat())
                Thread.sleep(delay.toLong())
                callback(true, null)
            } catch (e: Exception) {
                // 方法3: Shell 命令降级
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
     * 降级策略：无障碍服务 → Shizuku InputManager → Shell命令
     */
    fun doubleTap(x: Int, y: Int, delay: Int, callback: (Boolean, String?) -> Unit) {
        executor.execute {
            try {
                // 方法1: 无障碍服务手势
                val a11yServiceForGesture =
                    if (AutoGLMAccessibilityService.isEnabled(context)) AutoGLMAccessibilityService.waitForInstance(1200) else null
                if (a11yServiceForGesture != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    android.util.Log.d("DeviceController", "Trying Accessibility gesture double tap...")
                     
                    val latch = java.util.concurrent.CountDownLatch(1)
                    var gestureSuccess = false
                     
                    mainHandler.post {
                        a11yServiceForGesture.performDoubleTap(x.toFloat(), y.toFloat()) { success ->
                            gestureSuccess = success
                            latch.countDown()
                        }
                    }
                    
                    if (latch.await(3, java.util.concurrent.TimeUnit.SECONDS) && gestureSuccess) {
                        Thread.sleep(delay.toLong())
                        callback(true, null)
                        return@execute
                    }
                }
                
                // 方法2: Shizuku InputManager 注入事件
                injectTap(x.toFloat(), y.toFloat())
                Thread.sleep(100)
                injectTap(x.toFloat(), y.toFloat())
                Thread.sleep(delay.toLong())
                callback(true, null)
            } catch (e: Exception) {
                // 方法3: Shell 命令降级
                try {
                    executeShellCommand("input tap $x $y && sleep 0.1 && input tap $x $y")
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
     * 降级策略：无障碍服务 → Shizuku InputManager → Shell命令
     */
    fun longPress(x: Int, y: Int, duration: Int, delay: Int, callback: (Boolean, String?) -> Unit) {
        executor.execute {
            try {
                // 方法1: 无障碍服务手势
                val a11yServiceForGesture =
                    if (AutoGLMAccessibilityService.isEnabled(context)) AutoGLMAccessibilityService.waitForInstance(1200) else null
                if (a11yServiceForGesture != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    android.util.Log.d("DeviceController", "Trying Accessibility gesture long press...")
                     
                    val latch = java.util.concurrent.CountDownLatch(1)
                    var gestureSuccess = false
                     
                    mainHandler.post {
                        a11yServiceForGesture.performLongPress(
                            x.toFloat(), y.toFloat(), duration.toLong()
                        ) { success ->
                            gestureSuccess = success
                            latch.countDown()
                        }
                    }
                    
                    if (latch.await(5, java.util.concurrent.TimeUnit.SECONDS) && gestureSuccess) {
                        Thread.sleep(delay.toLong())
                        callback(true, null)
                        return@execute
                    }
                }
                
                // 方法2: Shizuku InputManager 注入事件
                injectSwipe(x.toFloat(), y.toFloat(), x.toFloat(), y.toFloat(), duration.toLong())
                Thread.sleep(delay.toLong())
                callback(true, null)
            } catch (e: Exception) {
                // 方法3: Shell 命令降级
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
     * 降级策略：无障碍服务 → Shizuku InputManager → Shell命令
     */
    fun swipe(startX: Int, startY: Int, endX: Int, endY: Int, 
              duration: Int, delay: Int, callback: (Boolean, String?) -> Unit) {
        executor.execute {
            try {
                // 方法1: 无障碍服务手势
                val a11yServiceForGesture =
                    if (AutoGLMAccessibilityService.isEnabled(context)) AutoGLMAccessibilityService.waitForInstance(1200) else null
                if (a11yServiceForGesture != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    android.util.Log.d("DeviceController", "Trying Accessibility gesture swipe...")
                     
                    val latch = java.util.concurrent.CountDownLatch(1)
                    var gestureSuccess = false
                     
                    mainHandler.post {
                        a11yServiceForGesture.performSwipe(
                            startX.toFloat(), startY.toFloat(),
                            endX.toFloat(), endY.toFloat(),
                            duration.toLong()
                        ) { success ->
                            gestureSuccess = success
                            latch.countDown()
                        }
                    }
                    
                    if (latch.await(5, java.util.concurrent.TimeUnit.SECONDS) && gestureSuccess) {
                        Thread.sleep(delay.toLong())
                        callback(true, null)
                        return@execute
                    }
                }
                
                // 方法2: Shizuku InputManager 注入事件
                injectSwipe(
                    startX.toFloat(), startY.toFloat(),
                    endX.toFloat(), endY.toFloat(),
                    duration.toLong()
                )
                Thread.sleep(delay.toLong())
                callback(true, null)
            } catch (e: Exception) {
                // 方法3: Shell 命令降级
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
     * 优先：Shizuku 剪贴板+粘贴（更可靠，支持微信等应用）
     * 回退：无障碍服务
     */
    fun typeText(text: String, callback: (Boolean, String?) -> Unit) {
        executor.execute {
            try {
                android.util.Log.d("DeviceController", "typeText: '$text'")
                
                // 1. 如果 Shizuku 已授权，优先使用剪贴板+粘贴
                if (Shizuku.pingBinder() && Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED) {
                    android.util.Log.d("DeviceController", "Shizuku available, trying clipboard+paste")
                    val shizukuResult = tryShizukuClipboardPaste(text)
                    if (shizukuResult) {
                        android.util.Log.d("DeviceController", "Shizuku clipboard+paste success")
                        callback(true, null)
                        return@execute
                    }
                    android.util.Log.w("DeviceController", "Shizuku failed, fallback to accessibility")
                }
                
                // 2. 回退到无障碍服务
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
                    
                    // 等待无障碍服务完成
                    latch.await(5, java.util.concurrent.TimeUnit.SECONDS)
                    
                    if (accessibilityResult) {
                        callback(true, null)
                        return@execute
                    }
                    
                    // 失败了，等待一下再重试
                    if (attempt < 3) {
                        android.util.Log.w("DeviceController", "Attempt $attempt failed, waiting before retry...")
                        Thread.sleep(500)
                    }
                }
                
                android.util.Log.e("DeviceController", "All 3 accessibility attempts failed")
                val reason = AutoGLMAccessibilityService.getLastInputFailure()
                val message = if (!reason.isNullOrBlank()) {
                    "文本输入失败：$reason"
                } else {
                    "文本输入失败，请确保输入框已获取焦点"
                }
                callback(false, message)
                
            } catch (e: Exception) {
                android.util.Log.e("DeviceController", "typeText error: ${e.message}", e)
                callback(false, e.message)
            }
        }
    }
    
    /**
     * 使用 Shizuku + ADB Keyboard 输入文本
     * 这是最可靠的中文输入方式，支持微信等应用
     */
    private fun tryShizukuClipboardPaste(text: String): Boolean {
        // 直接调用 ADB Keyboard 输入方法
        return tryAdbKeyboardInput(text)
    }
    
    /**
     * 使用ADB方式输入文字并回调
     */
    private fun tryAdbKeyboardAndCallback(text: String, callback: (Boolean, String?) -> Unit) {
        try {
            // 方法2: 尝试使用ADB Keyboard (支持中文)
            val adbKeyboardResult = tryAdbKeyboardInput(text)
            if (adbKeyboardResult) {
                android.util.Log.d("DeviceController", "ADB Keyboard input success")
                callback(true, null)
                return
            }
            
            // 方法3: 使用input text命令 (仅支持ASCII)
            val inputTextResult = tryInputTextCommand(text)
            if (inputTextResult) {
                android.util.Log.d("DeviceController", "input text command success")
                callback(true, null)
                return
            }
            
            android.util.Log.e("DeviceController", "All input methods failed")
            callback(false, "All input methods failed. Please install ADB Keyboard for Chinese input.")
            
        } catch (e: Exception) {
            android.util.Log.e("DeviceController", "ADB input error: ${e.message}", e)
            callback(false, e.message)
        }
    }
    
    /**
     * 使用ADB Keyboard输入文本
     * 严格按照原Python实现
     */
    private fun tryAdbKeyboardInput(text: String): Boolean {
        return try {
            android.util.Log.d("DeviceController", "tryAdbKeyboardInput: $text")
            
            // 检查ADB Keyboard是否安装
            val packageCheck = executeShizukuShellCommand("pm list packages com.android.adbkeyboard")
            android.util.Log.d("DeviceController", "Package check: $packageCheck")
            
            if (!packageCheck.contains("com.android.adbkeyboard")) {
                android.util.Log.w("DeviceController", "ADB Keyboard not installed")
                return false
            }
            
            // 获取当前输入法
            val originalIme = executeShizukuShellCommand("settings get secure default_input_method").trim()
            android.util.Log.d("DeviceController", "Original IME: $originalIme")
            
            // 切换到ADB Keyboard（如果还没有）
            if (!originalIme.contains("com.android.adbkeyboard")) {
                val setResult = executeShizukuShellCommand("ime set com.android.adbkeyboard/.AdbIME")
                android.util.Log.d("DeviceController", "ime set result: $setResult")
                Thread.sleep(500)
            }
            
            // 清除现有文本 - 使用与Python相同的命令格式
            val clearResult = executeShizukuShellCommand("am broadcast -a ADB_CLEAR_TEXT")
            android.util.Log.d("DeviceController", "Clear result: $clearResult")
            Thread.sleep(200)
            
            // Base64编码 - 与Python实现一致
            val encodedText = android.util.Base64.encodeToString(
                text.toByteArray(Charsets.UTF_8),
                android.util.Base64.NO_WRAP
            )
            android.util.Log.d("DeviceController", "Encoded text: $encodedText")
            
            // 发送广播 - 不使用引号，与Python实现完全一致
            // Python: am broadcast -a ADB_INPUT_B64 --es msg <base64>
            val broadcastResult = executeShizukuShellCommand("am broadcast -a ADB_INPUT_B64 --es msg $encodedText")
            android.util.Log.d("DeviceController", "Broadcast result: $broadcastResult")
            Thread.sleep(300)
            
            // 检查广播是否成功
            val success = broadcastResult.contains("result=0") || broadcastResult.contains("Broadcast completed")
            android.util.Log.d("DeviceController", "ADB Keyboard success: $success")
            
            // 恢复原输入法（可选，保持ADB Keyboard可能更好）
            // if (originalIme.isNotEmpty() && !originalIme.contains("com.android.adbkeyboard") && originalIme != "null") {
            //     executeShizukuShellCommand("ime set $originalIme")
            // }
            
            success
        } catch (e: Exception) {
            android.util.Log.e("DeviceController", "ADB Keyboard error: ${e.message}", e)
            false
        }
    }
    
    /**
     * 使用input text命令输入
     * 注意：只支持ASCII字符
     */
    private fun tryInputTextCommand(text: String): Boolean {
        return try {
            android.util.Log.d("DeviceController", "tryInputTextCommand: $text")
            
            // 检查是否包含非ASCII字符
            if (!text.all { it.code < 128 }) {
                android.util.Log.w("DeviceController", "Text contains non-ASCII characters, skipping input text")
                return false
            }
            
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
            
            val result = executeShizukuShellCommand("input text \"$escapedText\"")
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
    private fun tryClipboardPaste(text: String): Boolean {
        return try {
            android.util.Log.d("DeviceController", "tryClipboardPaste: $text")
            
            // 使用am命令设置剪贴板（需要Android 10+）
            val escaped = text.replace("'", "'\\''")
            executeShizukuShellCommand("am broadcast -a clipper.set -e text '$escaped'")
            Thread.sleep(200)
            
            // 模拟长按触发粘贴菜单
            // 或直接使用 input keyevent
            executeShizukuShellCommand("input keyevent 279") // KEYCODE_PASTE
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
    fun clearText(callback: (Boolean, String?) -> Unit) {
        executor.execute {
            try {
                // 优先使用无障碍服务
                val a11yService =
                    if (AutoGLMAccessibilityService.isEnabled(context)) AutoGLMAccessibilityService.waitForInstance(1200) else null
                if (a11yService != null) {
                    mainHandler.post {
                        val result = a11yService.clearText()
                        callback(result, if (result) null else "Failed to clear text")
                    }
                    return@execute
                }
                 
                // 回退到ADB广播
                executeShizukuShellCommand("am broadcast -a ADB_CLEAR_TEXT")
                Thread.sleep(300)
                callback(true, null)
            } catch (e: Exception) {
                callback(false, e.message)
            }
        }
    }
    
    /**
     * 按返回键
     */
    fun pressBack(delay: Int, callback: (Boolean, String?) -> Unit) {
        executor.execute {
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
    fun pressHome(delay: Int, callback: (Boolean, String?) -> Unit) {
        executor.execute {
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
