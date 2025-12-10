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
     * 注意：需要MediaProjection权限或Shizuku权限
     */
    fun getScreenshot(timeout: Int, callback: (Bitmap?, Boolean) -> Unit) {
        executor.execute {
            try {
                // 尝试通过Shizuku执行screencap命令
                if (Shizuku.pingBinder() && 
                    Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED) {
                    
                    val process = Runtime.getRuntime().exec(arrayOf(
                        "su", "-c", "screencap -p"
                    ))
                    
                    val inputStream = process.inputStream
                    val bitmap = android.graphics.BitmapFactory.decodeStream(inputStream)
                    inputStream.close()
                    
                    if (bitmap != null) {
                        callback(bitmap, false)
                        return@execute
                    }
                }
                
                // 如果Shizuku不可用，返回空
                callback(null, false)
                
            } catch (e: Exception) {
                e.printStackTrace()
                // 检查是否是安全页面导致的失败
                val isSensitive = e.message?.contains("secure") == true
                callback(null, isSensitive)
            }
        }
    }
    
    /**
     * 获取当前前台应用
     */
    fun getCurrentApp(): String {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
                val usageStatsManager = context.getSystemService(Context.USAGE_STATS_SERVICE) 
                    as UsageStatsManager
                val endTime = System.currentTimeMillis()
                val beginTime = endTime - 5000
                
                val usageStats = usageStatsManager.queryUsageStats(
                    UsageStatsManager.INTERVAL_BEST, beginTime, endTime
                )
                
                if (usageStats.isNotEmpty()) {
                    val sortedStats = usageStats.sortedByDescending { it.lastTimeUsed }
                    val packageName = sortedStats.firstOrNull()?.packageName
                    
                    if (packageName != null) {
                        return getAppNameFromPackage(packageName) ?: packageName
                    }
                }
            }
            "System Home"
        } catch (e: Exception) {
            "System Home"
        }
    }
    
    /**
     * 从包名获取应用名称
     */
    private fun getAppNameFromPackage(packageName: String): String? {
        return try {
            val pm = context.packageManager
            val appInfo = pm.getApplicationInfo(packageName, 0)
            pm.getApplicationLabel(appInfo).toString()
        } catch (e: Exception) {
            null
        }
    }
    
    /**
     * 点击操作
     */
    fun tap(x: Int, y: Int, delay: Int, callback: (Boolean, String?) -> Unit) {
        executor.execute {
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
    fun doubleTap(x: Int, y: Int, delay: Int, callback: (Boolean, String?) -> Unit) {
        executor.execute {
            try {
                injectTap(x.toFloat(), y.toFloat())
                Thread.sleep(100)
                injectTap(x.toFloat(), y.toFloat())
                Thread.sleep(delay.toLong())
                callback(true, null)
            } catch (e: Exception) {
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
     */
    fun longPress(x: Int, y: Int, duration: Int, delay: Int, callback: (Boolean, String?) -> Unit) {
        executor.execute {
            try {
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
              duration: Int, delay: Int, callback: (Boolean, String?) -> Unit) {
        executor.execute {
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
     */
    fun typeText(text: String, callback: (Boolean, String?) -> Unit) {
        executor.execute {
            try {
                // 使用ADB键盘广播方式输入
                val encodedText = android.util.Base64.encodeToString(
                    text.toByteArray(Charsets.UTF_8),
                    android.util.Base64.NO_WRAP
                )
                
                executeShellCommand(
                    "am broadcast -a ADB_INPUT_B64 --es msg $encodedText"
                )
                Thread.sleep(500)
                callback(true, null)
            } catch (e: Exception) {
                // 降级：逐字符输入
                try {
                    val escapedText = text.replace(" ", "%s")
                        .replace("'", "\\'")
                        .replace("\"", "\\\"")
                    executeShellCommand("input text '$escapedText'")
                    Thread.sleep(500)
                    callback(true, null)
                } catch (e2: Exception) {
                    callback(false, e2.message)
                }
            }
        }
    }
    
    /**
     * 清除文本
     */
    fun clearText(callback: (Boolean, String?) -> Unit) {
        executor.execute {
            try {
                executeShellCommand("am broadcast -a ADB_CLEAR_TEXT")
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
     * 执行Shell命令
     */
    private fun executeShellCommand(command: String): String {
        return if (Shizuku.pingBinder() && 
                   Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED) {
            // 通过Shizuku执行命令
            val process = Runtime.getRuntime().exec(arrayOf("sh", "-c", command))
            process.waitFor()
            process.inputStream.bufferedReader().readText()
        } else {
            // 直接执行（需要root或系统权限）
            val process = Runtime.getRuntime().exec(arrayOf("sh", "-c", command))
            process.waitFor()
            process.inputStream.bufferedReader().readText()
        }
    }
    
    /**
     * 释放资源
     */
    fun release() {
        executor.shutdown()
        handlerThread.quitSafely()
    }
}
