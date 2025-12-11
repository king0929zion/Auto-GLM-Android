package com.autoglm.auto_glm_mobile

import android.app.Service
import android.content.Intent
import android.graphics.PixelFormat
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.view.animation.AlphaAnimation
import android.view.animation.Animation
import android.view.animation.LinearInterpolator
import android.widget.TextView
import android.widget.LinearLayout
import android.widget.Button

/**
 * 悬浮窗服务
 * 1. 运行指示器 - 小型胶囊状
 * 2. Takeover弹窗 - 大型提示框
 */
class FloatingWindowService : Service() {
    
    private var windowManager: WindowManager? = null
    private var floatingView: View? = null
    private var statusText: TextView? = null
    private var indicator: View? = null
    private var layoutParams: WindowManager.LayoutParams? = null
    
    // Takeover弹窗
    private var takeoverView: View? = null
    private var takeoverParams: WindowManager.LayoutParams? = null
    private var takeoverMessageText: TextView? = null
    
    companion object {
        private var instance: FloatingWindowService? = null
        
        fun updateContent(content: String) {
            instance?.updateStatus(content)
        }
        
        fun show(content: String) {
            instance?.showWindow()
            instance?.updateStatus(content)
        }
        
        fun hide() {
            instance?.hideWindow()
        }
        
        fun showTakeover(message: String) {
            instance?.showTakeoverAlert(message)
        }
        
        fun hideTakeover() {
            instance?.hideTakeoverAlert()
        }
    }
    
    override fun onCreate() {
        super.onCreate()
        instance = this
        
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        createFloatingWindow()
        createTakeoverWindow()
    }
    
    override fun onDestroy() {
        super.onDestroy()
        instance = null
        removeFloatingWindow()
        removeTakeoverWindow()
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.getStringExtra("action")
        val content = intent?.getStringExtra("content") ?: "运行中..."
        
        when (action) {
            "show" -> {
                showWindow()
                updateStatus(content)
            }
            "hide" -> hideWindow()
            "update" -> updateStatus(content)
            "takeover" -> showTakeoverAlert(content)
            "hideTakeover" -> hideTakeoverAlert()
        }
        
        return START_STICKY
    }
    
    private fun createFloatingWindow() {
        // 主容器 - 小型胶囊状
        val container = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(32, 16, 32, 16) // 增加内边距
            
            // 半透明深色圆角背景 + 描边
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#E61E1E1E")) // 更不透明
                cornerRadius = 60f
                setStroke(2, Color.parseColor("#33FFFFFF")) // 细微描边
            }
        }
        
        // 绿色运行指示器小圆点
        indicator = View(this).apply {
            layoutParams = LinearLayout.LayoutParams(20, 20).apply {
                marginEnd = 16
            }
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor("#00E676")) // 更亮的绿色
                setStroke(2, Color.WHITE) // 白色描边
            }
        }
        
        // 状态文字
        statusText = TextView(this).apply {
            text = "🤖 AutoGLM 运行中"
            textSize = 13f
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            setTextColor(Color.WHITE)
            maxLines = 1
        }
        
        container.addView(indicator)
        container.addView(statusText)
        
        // 点击返回 App
        container.setOnClickListener {
             try {
                val intent = packageManager.getLaunchIntentForPackage(packageName)
                if (intent != null) {
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                }
             } catch (e: Exception) {
                 e.printStackTrace()
             }
        }
        
        floatingView = container
        
        // 配置窗口参数 - 小窗口，顶部居中
        layoutParams = WindowManager.LayoutParams().apply {
            width = WindowManager.LayoutParams.WRAP_CONTENT
            height = WindowManager.LayoutParams.WRAP_CONTENT
            x = 0
            y = 100
            gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            
            type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            }
            
            flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
            
            format = PixelFormat.TRANSLUCENT
        }
        
        // 添加拖动功能
        container.setOnTouchListener(object : View.OnTouchListener {
            private var initialX = 0
            private var initialY = 0
            private var initialTouchX = 0f
            private var initialTouchY = 0f
            
            override fun onTouch(v: View, event: MotionEvent): Boolean {
                when (event.action) {
                    MotionEvent.ACTION_DOWN -> {
                        initialX = layoutParams?.x ?: 0
                        initialY = layoutParams?.y ?: 0
                        initialTouchX = event.rawX
                        initialTouchY = event.rawY
                        return true
                    }
                    MotionEvent.ACTION_MOVE -> {
                        layoutParams?.x = initialX + (event.rawX - initialTouchX).toInt()
                        layoutParams?.y = initialY + (event.rawY - initialTouchY).toInt()
                        try {
                            windowManager?.updateViewLayout(floatingView, layoutParams)
                        } catch (e: Exception) {
                            // Ignore
                        }
                        return true
                    }
                }
                return false
            }
        })
        
        // 添加呼吸动画
        startBreathingAnimation()
        
        try {
            windowManager?.addView(floatingView, layoutParams)
            floatingView?.visibility = View.GONE // 初始隐藏
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
    
    /**
     * 创建Takeover弹窗
     */
    private fun createTakeoverWindow() {
        val displayMetrics = resources.displayMetrics
        val screenWidth = displayMetrics.widthPixels
        
        // 主容器
        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(48, 40, 48, 40)
            
            // 橙色警告背景
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#F57C00"))
                cornerRadius = 24f
            }
        }
        
        // 警告图标
        val iconText = TextView(this).apply {
            text = "⚠️"
            textSize = 48f
            gravity = Gravity.CENTER
        }
        
        // 标题
        val titleText = TextView(this).apply {
            text = "需要用户接管"
            textSize = 20f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            setPadding(0, 16, 0, 8)
        }
        
        // 消息内容
        takeoverMessageText = TextView(this).apply {
            text = "请完成当前操作后点击继续"
            textSize = 14f
            setTextColor(Color.parseColor("#FFFFFF"))
            gravity = Gravity.CENTER
            setPadding(0, 8, 0, 24)
            maxLines = 5
        }
        
        // 继续按钮
        val continueButton = Button(this).apply {
            text = "✓ 已完成，继续"
            textSize = 16f
            setTextColor(Color.parseColor("#F57C00"))
            background = GradientDrawable().apply {
                setColor(Color.WHITE)
                cornerRadius = 20f
            }
            setPadding(48, 24, 48, 24)
            
            setOnClickListener {
                hideTakeoverAlert()
            }
        }
        
        container.addView(iconText)
        container.addView(titleText)
        container.addView(takeoverMessageText)
        container.addView(continueButton)
        
        takeoverView = container
        
        // 配置Takeover窗口参数 - 居中显示
        takeoverParams = WindowManager.LayoutParams().apply {
            width = (screenWidth * 0.85).toInt()
            height = WindowManager.LayoutParams.WRAP_CONTENT
            gravity = Gravity.CENTER
            
            type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            }
            
            // 不使用FLAG_NOT_FOCUSABLE，让用户可以点击按钮
            flags = WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
            
            format = PixelFormat.TRANSLUCENT
        }
        
        try {
            windowManager?.addView(takeoverView, takeoverParams)
            takeoverView?.visibility = View.GONE
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
    
    private fun startBreathingAnimation() {
        val animation = AlphaAnimation(1.0f, 0.4f).apply {
            duration = 800
            interpolator = LinearInterpolator()
            repeatMode = Animation.REVERSE
            repeatCount = Animation.INFINITE
        }
        indicator?.startAnimation(animation)
    }
    
    private fun removeFloatingWindow() {
        try {
            indicator?.clearAnimation()
            floatingView?.let {
                windowManager?.removeView(it)
            }
            floatingView = null
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
    
    private fun removeTakeoverWindow() {
        try {
            takeoverView?.let {
                windowManager?.removeView(it)
            }
            takeoverView = null
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
    
    fun updateStatus(content: String) {
        floatingView?.post {
            val shortContent = if (content.length > 25) {
                "${content.take(25)}..."
            } else {
                content
            }
            statusText?.text = "🤖 $shortContent"
        }
    }
    
    fun showWindow() {
        floatingView?.post {
            floatingView?.visibility = View.VISIBLE
            startBreathingAnimation()
        }
    }
    
    fun hideWindow() {
        floatingView?.post {
            indicator?.clearAnimation()
            floatingView?.visibility = View.GONE
        }
    }
    
    fun showTakeoverAlert(message: String) {
        takeoverView?.post {
            takeoverMessageText?.text = message
            takeoverView?.visibility = View.VISIBLE
            
            // 同时隐藏运行指示器
            floatingView?.visibility = View.GONE
        }
    }
    
    fun hideTakeoverAlert() {
        takeoverView?.post {
            takeoverView?.visibility = View.GONE
            
            // 恢复运行指示器
            floatingView?.visibility = View.VISIBLE
            startBreathingAnimation()
        }
    }
}
