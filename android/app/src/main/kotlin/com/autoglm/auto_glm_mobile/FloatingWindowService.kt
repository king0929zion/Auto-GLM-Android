package com.autoglm.auto_glm_mobile

import android.app.Service
import android.content.Intent
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.TextView
import android.widget.LinearLayout
import android.graphics.Color
import android.graphics.drawable.GradientDrawable

/**
 * 悬浮窗服务 - 显示AI当前步骤
 * 半透明黑色背景，圆角设计，类似应用内的动作卡片
 */
class FloatingWindowService : Service() {
    
    private var windowManager: WindowManager? = null
    private var floatingView: View? = null
    private var actionTextView: TextView? = null
    private var stepTextView: TextView? = null
    private var layoutParams: WindowManager.LayoutParams? = null
    
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
        // 主容器 - 半透明黑色背景，圆角
        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(36, 24, 36, 24)
            
            // 半透明黑色圆角背景
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#CC1A1A1A")) // 80%透明度黑色
                cornerRadius = 24f
            }
            
            // 设置最小宽度
            minimumWidth = 280
        }
        
        // 顶部：图标和标题行
        val headerLayout = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        
        // AI图标
        val iconView = TextView(this).apply {
            text = "🤖"
            textSize = 16f
            setPadding(0, 0, 12, 0)
        }
        
        // 标题
        val titleView = TextView(this).apply {
            text = "AutoGLM"
            textSize = 14f
            setTextColor(Color.parseColor("#A5D6A7")) // 浅绿色
            setTypeface(null, Typeface.BOLD)
        }
        
        headerLayout.addView(iconView)
        headerLayout.addView(titleView)
        
        // 分隔线
        val divider = View(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                1
            ).apply {
                topMargin = 12
                bottomMargin = 12
            }
            setBackgroundColor(Color.parseColor("#404040"))
        }
        
        // 步骤标签
        stepTextView = TextView(this).apply {
            text = "执行中..."
            textSize = 11f
            setTextColor(Color.parseColor("#888888"))
            setPadding(0, 0, 0, 6)
        }
        
        // 动作内容 - 主要显示区域
        actionTextView = TextView(this).apply {
            text = "等待任务..."
            textSize = 15f
            setTextColor(Color.WHITE)
            maxLines = 3
            maxWidth = 500
            setLineSpacing(4f, 1f)
        }
        
        // 添加所有视图
        container.addView(headerLayout)
        container.addView(divider)
        container.addView(stepTextView)
        container.addView(actionTextView)
        
        floatingView = container
        
        // 配置窗口参数
        layoutParams = WindowManager.LayoutParams().apply {
            width = WindowManager.LayoutParams.WRAP_CONTENT
            height = WindowManager.LayoutParams.WRAP_CONTENT
            x = 30
            y = 150
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
        floatingView?.post {
            // 解析内容格式: "步骤 X: ActionName" 或 "正在处理: xxx"
            if (content.startsWith("步骤")) {
                val parts = content.split(":", limit = 2)
                if (parts.size == 2) {
                    stepTextView?.text = parts[0].trim()
                    actionTextView?.text = getActionDisplayName(parts[1].trim())
                } else {
                    stepTextView?.text = "执行中"
                    actionTextView?.text = content
                }
            } else if (content.startsWith("正在处理")) {
                stepTextView?.text = "任务"
                actionTextView?.text = content.replace("正在处理:", "").replace("正在处理：", "").trim()
            } else {
                stepTextView?.text = "执行中"
                actionTextView?.text = content
            }
        }
    }
    
    /**
     * 获取动作的友好显示名称
     */
    private fun getActionDisplayName(action: String): String {
        return when (action.lowercase()) {
            "tap" -> "👆 点击"
            "swipe" -> "👋 滑动"
            "type" -> "⌨️ 输入文字"
            "type_name" -> "⌨️ 输入姓名"
            "launch" -> "🚀 启动应用"
            "back" -> "◀️ 返回"
            "home" -> "🏠 回到主屏"
            "wait" -> "⏳ 等待"
            "double tap" -> "👆👆 双击"
            "long press" -> "👆⏱️ 长按"
            "finish" -> "✅ 完成"
            else -> "🎯 $action"
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
