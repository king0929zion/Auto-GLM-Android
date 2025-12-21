package com.autoglm.auto_glm_mobile

import android.content.Context
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.Image
import android.media.ImageReader
import android.os.Handler
import android.os.HandlerThread
import android.util.DisplayMetrics
import android.util.Log
import android.view.Surface
import android.view.WindowManager
import java.io.ByteArrayOutputStream
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference

/**
 * 虚拟屏幕管理器
 * 创建一个独立的虚拟显示屏，AI可以在上面执行任务而不影响用户主屏幕
 */
class VirtualScreenManager private constructor(private val context: Context) {

    companion object {
        private const val TAG = "VirtualScreenManager"
        private const val VIRTUAL_DISPLAY_NAME = "AutoZiVirtualDisplay"

        @Volatile
        private var instance: VirtualScreenManager? = null

        fun getInstance(context: Context): VirtualScreenManager {
            return instance ?: synchronized(this) {
                instance ?: VirtualScreenManager(context.applicationContext).also { instance = it }
            }
        }
    }

    // 虚拟显示相关
    private var virtualDisplay: VirtualDisplay? = null
    private var imageReader: ImageReader? = null
    private var displayId: Int? = null
    private val isActive = AtomicBoolean(false)
    
    // 屏幕参数
    private var screenWidth: Int = 1080
    private var screenHeight: Int = 2400
    private var screenDensity: Int = 420
    
    // 后台线程和Handler
    private val handlerThread = HandlerThread("VirtualScreenThread")
    private val handler: Handler
    
    // 最新帧缓存
    private val latestFrame = AtomicReference<Bitmap?>(null)
    
    // 帧回调
    private var onFrameCallback: ((Bitmap) -> Unit)? = null

    init {
        handlerThread.start()
        handler = Handler(handlerThread.looper)
        initDisplayMetrics()
    }

    /**
     * 初始化屏幕参数
     */
    private fun initDisplayMetrics() {
        try {
            val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
            val display = windowManager.defaultDisplay
            val metrics = DisplayMetrics()
            display.getRealMetrics(metrics)
            val statusBarHeight = getStatusBarHeight()

            screenWidth = metrics.widthPixels
            screenHeight = (metrics.heightPixels - statusBarHeight).coerceAtLeast(1)
            screenDensity = metrics.densityDpi
            
            Log.d(TAG, "Screen size: ${screenWidth}x${screenHeight}, density: $screenDensity")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get display metrics", e)
        }
    }

    private fun getStatusBarHeight(): Int {
        val resourceId = context.resources.getIdentifier("status_bar_height", "dimen", "android")
        return if (resourceId > 0) context.resources.getDimensionPixelSize(resourceId) else 0
    }

    /**
     * 创建虚拟屏幕
     * @return 虚拟屏幕的Display ID，失败返回null
     */
    fun createVirtualDisplay(): Int? {
        if (isActive.get() && displayId != null) {
            Log.d(TAG, "Virtual display already exists: $displayId")
            return displayId
        }
        
        return try {
            val displayManager = context.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
            
            // 创建ImageReader用于捕获帧
            imageReader = ImageReader.newInstance(
                screenWidth,
                screenHeight,
                PixelFormat.RGBA_8888,
                2
            ).apply {
                setOnImageAvailableListener({ reader ->
                    processFrame(reader)
                }, handler)
            }
            
            val surface: Surface = imageReader!!.surface
            
            // 创建虚拟显示
            val flags = DisplayManager.VIRTUAL_DISPLAY_FLAG_PUBLIC or
                    DisplayManager.VIRTUAL_DISPLAY_FLAG_PRESENTATION
            
            virtualDisplay = displayManager.createVirtualDisplay(
                VIRTUAL_DISPLAY_NAME,
                screenWidth,
                screenHeight,
                screenDensity,
                surface,
                flags
            )
            
            displayId = virtualDisplay?.display?.displayId
            isActive.set(true)
            
            Log.d(TAG, "Created virtual display: id=$displayId, size=${screenWidth}x${screenHeight}")
            displayId
        } catch (e: Exception) {
            Log.e(TAG, "Failed to create virtual display", e)
            release()
            null
        }
    }

    /**
     * 处理新帧
     */
    private fun processFrame(reader: ImageReader) {
        var image: Image? = null
        try {
            image = reader.acquireLatestImage()
            if (image == null) return
            
            val width = image.width
            val height = image.height
            if (width <= 0 || height <= 0) return
            
            val plane = image.planes[0]
            val buffer = plane.buffer
            val pixelStride = plane.pixelStride
            val rowStride = plane.rowStride
            val rowPadding = rowStride - pixelStride * width
            
            // 创建位图
            val bitmap = Bitmap.createBitmap(
                width + rowPadding / pixelStride,
                height,
                Bitmap.Config.ARGB_8888
            )
            bitmap.copyPixelsFromBuffer(buffer)
            
            // 裁剪到正确尺寸
            val croppedBitmap = if (rowPadding > 0) {
                Bitmap.createBitmap(bitmap, 0, 0, width, height)
            } else {
                bitmap
            }
            
            // 更新缓存
            latestFrame.getAndSet(croppedBitmap)?.recycle()
            
            // 回调通知
            onFrameCallback?.invoke(croppedBitmap)
            
        } catch (e: Exception) {
            Log.e(TAG, "Error processing frame", e)
        } finally {
            try {
                image?.close()
            } catch (_: Exception) {}
        }
    }

    /**
     * 获取最新帧
     */
    fun getLatestFrame(): Bitmap? {
        return latestFrame.get()?.let { 
            Bitmap.createBitmap(it) // 返回副本
        }
    }

    /**
     * 获取最新帧的JPEG字节数组（用于传输到Flutter）
     */
    fun getLatestFrameAsJpeg(quality: Int = 80): ByteArray? {
        return latestFrame.get()?.let { bitmap ->
            try {
                ByteArrayOutputStream().use { stream ->
                    bitmap.compress(Bitmap.CompressFormat.JPEG, quality, stream)
                    stream.toByteArray()
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to compress bitmap", e)
                null
            }
        }
    }

    /**
     * 设置帧回调
     */
    fun setOnFrameCallback(callback: ((Bitmap) -> Unit)?) {
        onFrameCallback = callback
    }

    /**
     * 获取虚拟屏幕ID
     */
    fun getDisplayId(): Int? = displayId

    /**
     * 检查虚拟屏幕是否激活
     */
    fun isActive(): Boolean = isActive.get()

    /**
     * 在虚拟屏幕上启动应用
     */
    fun launchAppOnVirtualDisplay(packageName: String): Boolean {
        val id = displayId ?: return false
        
        return try {
            val pm = context.packageManager
            val launchIntent = pm.getLaunchIntentForPackage(packageName)
            
            if (launchIntent == null) {
                Log.e(TAG, "No launch intent for package: $packageName")
                return false
            }
            
            launchIntent.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
            launchIntent.addFlags(android.content.Intent.FLAG_ACTIVITY_MULTIPLE_TASK)
            
            // 设置目标显示屏
            val options = android.app.ActivityOptions.makeBasic()
            options.launchDisplayId = id
            
            context.startActivity(launchIntent, options.toBundle())
            Log.d(TAG, "Launched $packageName on virtual display $id")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to launch app on virtual display", e)
            false
        }
    }

    /**
     * 截取虚拟屏幕
     */
    fun captureScreen(): Bitmap? {
        return getLatestFrame()
    }

    /**
     * 释放虚拟屏幕资源
     */
    fun release() {
        Log.d(TAG, "Releasing virtual display resources")
        
        isActive.set(false)
        
        try {
            virtualDisplay?.release()
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing virtual display", e)
        }
        virtualDisplay = null
        
        try {
            imageReader?.close()
        } catch (e: Exception) {
            Log.e(TAG, "Error closing image reader", e)
        }
        imageReader = null
        
        latestFrame.getAndSet(null)?.recycle()
        displayId = null
        onFrameCallback = null
    }

    /**
     * 获取屏幕尺寸
     */
    fun getScreenSize(): Pair<Int, Int> = screenWidth to screenHeight

    /**
     * 获取屏幕密度
     */
    fun getScreenDensity(): Int = screenDensity
}
