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

/**
 * 简单的运行指示器悬浮窗
 * 只显示一个小圆点和简单的状态文字
 */
class FloatingWindowService : Service() {
    
    private var windowManager: WindowManager? = null
    private var floatingView: View? = null
    private var statusText: TextView? = null
    private var indicator: View? = null
    private var layoutParams: WindowManager.LayoutParams? = null
    
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
    }
    
    override fun onCreate() {
        super.onCreate()
        instance = this
        
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        createFloatingWindow()
    }
    
    override fun onDestroy() {
        super.onDestroy()
        instance = null
        removeFloatingWindow()
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
        }
        
        return START_STICKY
    }
    
    private fun createFloatingWindow() {
        // 主容器 - 小型胶囊状
        val container = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(24, 12, 24, 12)
            
            // 半透明黑色圆角背景
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#DD1A1A1A"))
                cornerRadius = 50f
            }
        }
        
        // 绿色运行指示器小圆点
        indicator = View(this).apply {
            layoutParams = LinearLayout.LayoutParams(16, 16).apply {
                marginEnd = 12
            }
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor("#4CAF50"))
            }
        }
        
        // 状态文字
        statusText = TextView(this).apply {
            text = "🤖 运行中"
            textSize = 12f
            setTextColor(Color.WHITE)
            maxLines = 1
        }
        
        container.addView(indicator)
        container.addView(statusText)
        
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
    
    fun updateStatus(content: String) {
        floatingView?.post {
            val shortContent = if (content.length > 15) {
                "${content.take(15)}..."
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
}
