package com.autoglm.auto_glm_mobile

import android.app.Service
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.TextView
import android.widget.LinearLayout
import android.graphics.Color
import android.graphics.drawable.GradientDrawable

/**
 * 悬浮窗服务 - 显示AI当前步骤
 */
class FloatingWindowService : Service() {
    
    private var windowManager: WindowManager? = null
    private var floatingView: View? = null
    private var textView: TextView? = null
    
    companion object {
        private var instance: FloatingWindowService? = null
        
        fun updateContent(content: String) {
            instance?.updateText(content)
        }
        
        fun show(content: String) {
            instance?.showWindow()
            instance?.updateText(content)
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
        val content = intent?.getStringExtra("content") ?: ""
        
        when (action) {
            "show" -> {
                showWindow()
                updateText(content)
            }
            "hide" -> hideWindow()
            "update" -> updateText(content)
        }
        
        return START_STICKY
    }
    
    private fun createFloatingWindow() {
        // 创建容器
        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(24, 16, 24, 16)
            
            // 创建圆角背景
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#E8F5E9")) // 浅绿色背景
                cornerRadius = 20f
                setStroke(2, Color.parseColor("#4CAF50"))
            }
        }
        
        // 创建标题
        val titleView = TextView(this).apply {
            text = "🤖 AutoGLM"
            textSize = 12f
            setTextColor(Color.parseColor("#2E7D32"))
        }
        
        // 创建内容文本
        textView = TextView(this).apply {
            text = "等待任务..."
            textSize = 14f
            setTextColor(Color.parseColor("#1B5E20"))
            maxLines = 5
            maxWidth = 600
        }
        
        container.addView(titleView)
        container.addView(textView)
        
        floatingView = container
        
        // 配置窗口参数
        val layoutParams = WindowManager.LayoutParams().apply {
            width = WindowManager.LayoutParams.WRAP_CONTENT
            height = WindowManager.LayoutParams.WRAP_CONTENT
            x = 0
            y = 200
            gravity = Gravity.TOP or Gravity.START
            
            type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            }
            
            flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
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
                        initialX = layoutParams.x
                        initialY = layoutParams.y
                        initialTouchX = event.rawX
                        initialTouchY = event.rawY
                        return true
                    }
                    MotionEvent.ACTION_MOVE -> {
                        layoutParams.x = initialX + (event.rawX - initialTouchX).toInt()
                        layoutParams.y = initialY + (event.rawY - initialTouchY).toInt()
                        windowManager?.updateViewLayout(floatingView, layoutParams)
                        return true
                    }
                }
                return false
            }
        })
        
        try {
            windowManager?.addView(floatingView, layoutParams)
            floatingView?.visibility = View.GONE // 初始隐藏
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
    
    private fun removeFloatingWindow() {
        try {
            floatingView?.let {
                windowManager?.removeView(it)
            }
            floatingView = null
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
    
    fun updateText(content: String) {
        textView?.post {
            textView?.text = content
        }
    }
    
    fun showWindow() {
        floatingView?.post {
            floatingView?.visibility = View.VISIBLE
        }
    }
    
    fun hideWindow() {
        floatingView?.post {
            floatingView?.visibility = View.GONE
        }
    }
}
