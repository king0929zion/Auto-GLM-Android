package com.autoglm.auto_glm_mobile

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Base64
import android.util.DisplayMetrics
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import rikka.shizuku.Shizuku
import rikka.shizuku.ShizukuBinderWrapper
import rikka.shizuku.ShizukuProvider
import rikka.shizuku.SystemServiceHelper
import java.io.ByteArrayOutputStream

/**
 * AutoGLM Mobile 主Activity
 * 负责Flutter与Android原生层的通信，实现设备控制功能
 */
class MainActivity : FlutterActivity() {
    
    companion object {
        private const val CHANNEL_NAME = "com.autoglm.mobile/device"
        private const val REQUEST_CODE_PERMISSION = 1001
    }
    
    private lateinit var methodChannel: MethodChannel
    private var deviceController: DeviceController? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // 创建方法通道
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
        methodChannel.setMethodCallHandler { call, result ->
            handleMethodCall(call, result)
        }
    }
    
    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> initialize(result)
            "getScreenshot" -> getScreenshot(call, result)
            "getCurrentApp" -> getCurrentApp(result)
            "tap" -> tap(call, result)
            "doubleTap" -> doubleTap(call, result)
            "longPress" -> longPress(call, result)
            "swipe" -> swipe(call, result)
            "typeText" -> typeText(call, result)
            "clearText" -> clearText(call, result)
            "pressBack" -> pressBack(call, result)
            "pressHome" -> pressHome(call, result)
            "launchApp" -> launchApp(call, result)
            "checkShizuku" -> checkShizukuStatus(result)
            "isShizukuInstalled" -> isShizukuInstalled(result)
            "isShizukuRunning" -> isShizukuRunning(result)
            "isShizukuAuthorized" -> isShizukuAuthorized(result)
            "requestShizukuPermission" -> requestShizukuPermission(result)
            "showFloatingWindow" -> showFloatingWindow(call, result)
            "hideFloatingWindow" -> hideFloatingWindow(result)
            "updateFloatingWindow" -> updateFloatingWindow(call, result)
            "showTakeover" -> showTakeover(call, result)
            "hideTakeover" -> hideTakeover(result)
            "isAccessibilityEnabled" -> isAccessibilityEnabled(result)
            "openAccessibilitySettings" -> openAccessibilitySettings(result)
            "checkOverlayPermission" -> checkOverlayPermission(result)
            "openOverlaySettings" -> openOverlaySettings(result)
            "isIgnoringBatteryOptimizations" -> isIgnoringBatteryOptimizations(result)
            "requestIgnoreBatteryOptimizations" -> requestIgnoreBatteryOptimizations(result)
            "startKeepAliveService" -> startKeepAliveService(result)
            "stopKeepAliveService" -> stopKeepAliveService(result)
            "isAutoZiImeEnabled" -> isAutoZiImeEnabled(result)
            "openInputMethodSettings" -> openInputMethodSettings(result)
            // 虚拟屏幕相关
            "createVirtualScreen" -> createVirtualScreen(result)
            "releaseVirtualScreen" -> releaseVirtualScreen(result)
            "getVirtualScreenFrame" -> getVirtualScreenFrame(result)
            "launchAppOnVirtualScreen" -> launchAppOnVirtualScreen(call, result)
            "isVirtualScreenActive" -> isVirtualScreenActive(result)
            else -> result.notImplemented()
        }
    }
    
    private fun showFloatingWindow(call: MethodCall, result: MethodChannel.Result) {
        val content = call.argument<String>("content") ?: ""
        val intent = Intent(this, FloatingWindowService::class.java).apply {
            putExtra("action", "show")
            putExtra("content", content)
        }
        startService(intent)
        result.success(true)
    }
    
    private fun hideFloatingWindow(result: MethodChannel.Result) {
        val intent = Intent(this, FloatingWindowService::class.java).apply {
            putExtra("action", "hide")
        }
        startService(intent)
        result.success(true)
    }
    
    private fun updateFloatingWindow(call: MethodCall, result: MethodChannel.Result) {
        val content = call.argument<String>("content") ?: ""
        val intent = Intent(this, FloatingWindowService::class.java).apply {
            putExtra("action", "update")
            putExtra("content", content)
        }
        startService(intent)
        result.success(true)
    }
    
    private fun showTakeover(call: MethodCall, result: MethodChannel.Result) {
        val message = call.argument<String>("message") ?: "请完成当前操作"
        val intent = Intent(this, FloatingWindowService::class.java).apply {
            putExtra("action", "takeover")
            putExtra("content", message)
        }
        startService(intent)
        result.success(true)
    }
    
    private fun hideTakeover(result: MethodChannel.Result) {
        val intent = Intent(this, FloatingWindowService::class.java).apply {
            putExtra("action", "hideTakeover")
        }
        startService(intent)
        result.success(true)
    }
    
    private fun isShizukuInstalled(result: MethodChannel.Result) {
        try {
            packageManager.getPackageInfo("moe.shizuku.privileged.api", 0)
            result.success(true)
        } catch (e: PackageManager.NameNotFoundException) {
            result.success(false)
        }
    }
    
    private fun isShizukuRunning(result: MethodChannel.Result) {
        try {
            result.success(Shizuku.pingBinder())
        } catch (e: Exception) {
            result.success(false)
        }
    }
    
    private fun isShizukuAuthorized(result: MethodChannel.Result) {
        try {
            if (!Shizuku.pingBinder()) {
                result.success(false)
                return
            }
            val granted = Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED
            result.success(granted)
        } catch (e: Exception) {
            result.success(false)
        }
    }
    
    private fun requestShizukuPermission(result: MethodChannel.Result) {
        try {
            if (!Shizuku.pingBinder()) {
                result.success(false)
                return
            }
            if (Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED) {
                result.success(true)
                return
            }
            Shizuku.requestPermission(REQUEST_CODE_PERMISSION)
            result.success(true)
        } catch (e: Exception) {
            result.success(false)
        }
    }
    
    /**
     * 初始化设备控制器
     */
    private fun initialize(result: MethodChannel.Result) {
        try {
            deviceController = DeviceController(this)
            
            val display = windowManager.defaultDisplay
            val metrics = DisplayMetrics()
            display.getRealMetrics(metrics)
            
            result.success(mapOf(
                "width" to metrics.widthPixels,
                "height" to metrics.heightPixels,
                "density" to metrics.density
            ))
        } catch (e: Exception) {
            result.error("INIT_ERROR", e.message, null)
        }
    }
    
    /**
     * 获取屏幕截图
     */
    private fun getScreenshot(call: MethodCall, result: MethodChannel.Result) {
        val timeout = call.argument<Int>("timeout") ?: 10000
        
        deviceController?.getScreenshot(timeout) { bitmap, isSensitive ->
            if (bitmap != null) {
                val stream = ByteArrayOutputStream()
                bitmap.compress(Bitmap.CompressFormat.PNG, 90, stream)
                val base64 = Base64.encodeToString(stream.toByteArray(), Base64.NO_WRAP)
                
                mainHandler.post {
                    result.success(mapOf(
                        "base64" to base64,
                        "width" to bitmap.width,
                        "height" to bitmap.height,
                        "isSensitive" to isSensitive
                    ))
                }
                bitmap.recycle()
            } else {
                mainHandler.post {
                    result.success(mapOf(
                        "base64" to "",
                        "width" to 1080,
                        "height" to 2400,
                        "isSensitive" to isSensitive
                    ))
                }
            }
        }
    }
    
    /**
     * 获取当前前台应用
     */
    private fun getCurrentApp(result: MethodChannel.Result) {
        try {
            val currentApp = deviceController?.getCurrentApp() ?: "System Home"
            result.success(currentApp)
        } catch (e: Exception) {
            result.success("System Home")
        }
    }
    
    /**
     * 点击操作
     */
    private fun tap(call: MethodCall, result: MethodChannel.Result) {
        val x = call.argument<Int>("x") ?: 0
        val y = call.argument<Int>("y") ?: 0
        val delay = call.argument<Int>("delay") ?: 1000
        val displayId = call.argument<Int>("displayId") ?: -1
        
        deviceController?.tap(x, y, delay, displayId) { success, message ->
            mainHandler.post {
                if (success) {
                    result.success(true)
                } else {
                    result.error("TAP_ERROR", message, null)
                }
            }
        }
    }
    
    /**
     * 双击操作
     */
    private fun doubleTap(call: MethodCall, result: MethodChannel.Result) {
        val x = call.argument<Int>("x") ?: 0
        val y = call.argument<Int>("y") ?: 0
        val delay = call.argument<Int>("delay") ?: 1000
        val displayId = call.argument<Int>("displayId") ?: -1
        
        deviceController?.doubleTap(x, y, delay, displayId) { success, message ->
            mainHandler.post {
                if (success) {
                    result.success(true)
                } else {
                    result.error("DOUBLE_TAP_ERROR", message, null)
                }
            }
        }
    }
    
    /**
     * 长按操作
     */
    private fun longPress(call: MethodCall, result: MethodChannel.Result) {
        val x = call.argument<Int>("x") ?: 0
        val y = call.argument<Int>("y") ?: 0
        val duration = call.argument<Int>("duration") ?: 3000
        val delay = call.argument<Int>("delay") ?: 1000
        val displayId = call.argument<Int>("displayId") ?: -1
        
        deviceController?.longPress(x, y, duration, delay, displayId) { success, message ->
            mainHandler.post {
                if (success) {
                    result.success(true)
                } else {
                    result.error("LONG_PRESS_ERROR", message, null)
                }
            }
        }
    }
    
    /**
     * 滑动操作
     */
    private fun swipe(call: MethodCall, result: MethodChannel.Result) {
        val startX = call.argument<Int>("startX") ?: 0
        val startY = call.argument<Int>("startY") ?: 0
        val endX = call.argument<Int>("endX") ?: 0
        val endY = call.argument<Int>("endY") ?: 0
        val duration = call.argument<Int>("duration") ?: 1000
        val delay = call.argument<Int>("delay") ?: 1000
        val displayId = call.argument<Int>("displayId") ?: -1
        
        deviceController?.swipe(startX, startY, endX, endY, duration, delay, displayId) { success, message ->
            mainHandler.post {
                if (success) {
                    result.success(true)
                } else {
                    result.error("SWIPE_ERROR", message, null)
                }
            }
        }
    }
    
    /**
     * 输入文本
     */
    private fun typeText(call: MethodCall, result: MethodChannel.Result) {
        val text = call.argument<String>("text") ?: ""
        val displayId = call.argument<Int>("displayId") ?: -1
        
        deviceController?.typeText(text, displayId) { success, message ->
            mainHandler.post {
                if (success) {
                    result.success(true)
                } else {
                    result.error("TYPE_ERROR", message, null)
                }
            }
        }
    }
    
    /**
     * 清除文本
     */
    private fun clearText(call: MethodCall, result: MethodChannel.Result) {
        val displayId = call.argument<Int>("displayId") ?: -1
        
        deviceController?.clearText(displayId) { success, message ->
            mainHandler.post {
                if (success) {
                    result.success(true)
                } else {
                    result.error("CLEAR_ERROR", message, null)
                }
            }
        }
    }
    
    /**
     * 按返回键
     */
    private fun pressBack(call: MethodCall, result: MethodChannel.Result) {
        val delay = call.argument<Int>("delay") ?: 1000
        val displayId = call.argument<Int>("displayId") ?: -1
        
        deviceController?.pressBack(delay, displayId) { success, message ->
            mainHandler.post {
                if (success) {
                    result.success(true)
                } else {
                    result.error("BACK_ERROR", message, null)
                }
            }
        }
    }
    
    /**
     * 按Home键
     */
    private fun pressHome(call: MethodCall, result: MethodChannel.Result) {
        val delay = call.argument<Int>("delay") ?: 1000
        val displayId = call.argument<Int>("displayId") ?: -1
        
        deviceController?.pressHome(delay, displayId) { success, message ->
            mainHandler.post {
                if (success) {
                    result.success(true)
                } else {
                    result.error("HOME_ERROR", message, null)
                }
            }
        }
    }
    
    /**
     * 启动应用
     */
    private fun launchApp(call: MethodCall, result: MethodChannel.Result) {
        val packageName = call.argument<String>("package") ?: ""
        
        try {
            val intent = packageManager.getLaunchIntentForPackage(packageName)
            if (intent != null) {
                startActivity(intent)
                result.success(true)
            } else {
                result.error("APP_NOT_FOUND", "Cannot find app: $packageName", null)
            }
        } catch (e: Exception) {
            result.error("LAUNCH_ERROR", e.message, null)
        }
    }
    
    /**
     * 检查Shizuku状态
     */
    private fun checkShizukuStatus(result: MethodChannel.Result) {
        try {
            if (!Shizuku.pingBinder()) {
                result.success(mapOf(
                    "status" to "not_started",
                    "message" to "Shizuku service not running"
                ))
                return
            }
            
            if (Shizuku.checkSelfPermission() != PackageManager.PERMISSION_GRANTED) {
                result.success(mapOf(
                    "status" to "not_authorized",
                    "message" to "Shizuku permission not granted"
                ))
                return
            }
            
            result.success(mapOf(
                "status" to "authorized",
                "message" to "Shizuku is ready"
            ))
        } catch (e: Exception) {
            result.success(mapOf(
                "status" to "error",
                "message" to e.message
            ))
        }
    }
    
    /**
     * 检查无障碍服务是否启用
     */
    private fun isAccessibilityEnabled(result: MethodChannel.Result) {
        result.success(AutoGLMAccessibilityService.isEnabled(this))
    }
    
    /**
     * 打开无障碍设置页面
     */
    private fun openAccessibilitySettings(result: MethodChannel.Result) {
        try {
            val intent = Intent(android.provider.Settings.ACTION_ACCESSIBILITY_SETTINGS)
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.success(false)
        }
    }
    
    /**
     * 检查悬浮窗权限
     */
    private fun checkOverlayPermission(result: MethodChannel.Result) {
        result.success(
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                android.provider.Settings.canDrawOverlays(this)
            } else {
                true
            }
        )
    }
    
    /**
     * 打开悬浮窗设置页面
     */
    private fun openOverlaySettings(result: MethodChannel.Result) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val intent = Intent(
                    android.provider.Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    android.net.Uri.parse("package:$packageName")
                )
                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                startActivity(intent)
            }
            result.success(true)
        } catch (e: Exception) {
            result.success(false)
        }
    }
    
    /**
     * 检查是否已忽略电池优化
     */
    private fun isIgnoringBatteryOptimizations(result: MethodChannel.Result) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val powerManager = getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
                result.success(powerManager.isIgnoringBatteryOptimizations(packageName))
            } else {
                result.success(true)
            }
        } catch (e: Exception) {
            result.success(false)
        }
    }
    
    /**
     * 请求忽略电池优化
     */
    private fun requestIgnoreBatteryOptimizations(result: MethodChannel.Result) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val intent = Intent(android.provider.Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                intent.data = android.net.Uri.parse("package:$packageName")
                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                startActivity(intent)
                result.success(true)
            } else {
                result.success(true)
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Request ignore battery optimizations error: ${e.message}")
            result.success(false)
        }
    }
    
    /**
     * 启动保活服务
     */
    private fun startKeepAliveService(result: MethodChannel.Result) {
        try {
            val serviceIntent = Intent(this, KeepAliveService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(serviceIntent)
            } else {
                startService(serviceIntent)
            }
            android.util.Log.d("MainActivity", "KeepAliveService started")
            result.success(true)
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Start KeepAliveService error: ${e.message}")
            result.success(false)
        }
    }
    
    /**
     * 停止保活服务
     */
    private fun stopKeepAliveService(result: MethodChannel.Result) {
        try {
            val serviceIntent = Intent(this, KeepAliveService::class.java)
            stopService(serviceIntent)
            android.util.Log.d("MainActivity", "KeepAliveService stopped")
            result.success(true)
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Stop KeepAliveService error: ${e.message}")
            result.success(false)
        }
    }
    
    /**
     * 检查 AutoZi 输入法是否已启用
     */
    private fun isAutoZiImeEnabled(result: MethodChannel.Result) {
        try {
            val inputMethodManager = getSystemService(INPUT_METHOD_SERVICE) as android.view.inputmethod.InputMethodManager
            val enabledInputMethods = inputMethodManager.enabledInputMethodList
            
            val autoZiEnabled = enabledInputMethods.any { 
                it.packageName == packageName && it.serviceName.contains("AutoZiInputMethod")
            }
            
            android.util.Log.d("MainActivity", "AutoZi IME enabled: $autoZiEnabled")
            result.success(autoZiEnabled)
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Check AutoZi IME error: ${e.message}")
            result.success(false)
        }
    }
    
    /**
     * 打开输入法设置页面
     */
    private fun openInputMethodSettings(result: MethodChannel.Result) {
        try {
            val intent = Intent(android.provider.Settings.ACTION_INPUT_METHOD_SETTINGS)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Open input method settings error: ${e.message}")
            result.success(false)
        }
    }
    
    // ========================================
    // 虚拟屏幕相关方法
    // ========================================
    
    /**
     * 创建虚拟屏幕
     */
    private fun createVirtualScreen(result: MethodChannel.Result) {
        try {
            val manager = VirtualScreenManager.getInstance(this)
            val displayId = manager.createVirtualDisplay()
            
            if (displayId != null) {
                val (width, height) = manager.getScreenSize()
                result.success(mapOf(
                    "displayId" to displayId,
                    "width" to width,
                    "height" to height,
                    "density" to manager.getScreenDensity()
                ))
            } else {
                result.error("CREATE_ERROR", "Failed to create virtual display", null)
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Create virtual screen error: ${e.message}")
            result.error("CREATE_ERROR", e.message, null)
        }
    }
    
    /**
     * 释放虚拟屏幕
     */
    private fun releaseVirtualScreen(result: MethodChannel.Result) {
        try {
            VirtualScreenManager.getInstance(this).release()
            result.success(true)
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Release virtual screen error: ${e.message}")
            result.success(false)
        }
    }
    
    /**
     * 获取虚拟屏幕最新帧
     */
    private fun getVirtualScreenFrame(result: MethodChannel.Result) {
        try {
            val manager = VirtualScreenManager.getInstance(this)
            val frameBytes = manager.getLatestFrameAsJpeg(85)
            
            if (frameBytes != null) {
                val base64 = Base64.encodeToString(frameBytes, Base64.NO_WRAP)
                val (width, height) = manager.getScreenSize()
                result.success(mapOf(
                    "base64" to base64,
                    "width" to width,
                    "height" to height
                ))
            } else {
                result.success(mapOf(
                    "base64" to "",
                    "width" to 0,
                    "height" to 0
                ))
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Get virtual screen frame error: ${e.message}")
            result.success(mapOf(
                "base64" to "",
                "width" to 0,
                "height" to 0
            ))
        }
    }
    
    /**
     * 在虚拟屏幕上启动应用
     */
    private fun launchAppOnVirtualScreen(call: MethodCall, result: MethodChannel.Result) {
        val packageName = call.argument<String>("package") ?: ""
        
        try {
            val manager = VirtualScreenManager.getInstance(this)
            
            if (manager.getDisplayId() == -1) {
                result.error("NO_DISPLAY", "Virtual display not created", null)
                return
            }
            
            val intent = packageManager.getLaunchIntentForPackage(packageName)
            if (intent != null) {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                intent.addFlags(Intent.FLAG_ACTIVITY_MULTIPLE_TASK)
                
                // 指定在虚拟屏幕启动
                val options = android.app.ActivityOptions.makeBasic()
                
                // 使用反射调用 setLaunchDisplayId (系统API)
                try {
                    val method = android.app.ActivityOptions::class.java.getMethod("setLaunchDisplayId", Int::class.javaPrimitiveType)
                    method.invoke(options, manager.getDisplayId())
                } catch (e: Exception) {
                    android.util.Log.e("MainActivity", "Failed to set launch display ID: ${e.message}")
                }
                
                startActivity(intent, options.toBundle())
                result.success(true)
            } else {
                result.error("APP_NOT_FOUND", "App not found: $packageName", null)
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Launch app on virtual screen error: ${e.message}")
            result.error("LAUNCH_ERROR", e.message, null)
        }
    }
    
    /**
     * 检查虚拟屏幕是否激活
     */
    private fun isVirtualScreenActive(result: MethodChannel.Result) {
        try {
            result.success(VirtualScreenManager.getInstance(this).isActive())
        } catch (e: Exception) {
            result.success(false)
        }
    }
    
    override fun onDestroy() {
        // 释放虚拟屏幕资源
        try {
            VirtualScreenManager.getInstance(this).release()
        } catch (_: Exception) {}
        
        deviceController?.release()
        super.onDestroy()
    }
}

