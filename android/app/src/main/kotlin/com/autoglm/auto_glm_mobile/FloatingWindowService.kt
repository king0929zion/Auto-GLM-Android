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
import android.widget.ScrollView
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.text.method.ScrollingMovementMethod

/**
 * 悬浮窗服务 - 显示AI当前步骤和思考过程
 * 更大的窗口，完整展示AI的思考和动作
 */
class FloatingWindowService : Service() {
    
    private var windowManager: WindowManager? = null
    private var floatingView: View? = null
    private var thinkingTextView: TextView? = null
    private var actionTextView: TextView? = null
    private var stepTextView: TextView? = null
    private var layoutParams: WindowManager.LayoutParams? = null
    private var isExpanded = true
    
    companion object {
        private var instance: FloatingWindowService? = null
        
        fun updateContent(content: String) {
            instance?.updateText(content)
        }
        
        fun updateThinking(thinking: String) {
            instance?.updateThinkingText(thinking)
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
        val thinking = intent?.getStringExtra("thinking") ?: ""
        
        when (action) {
            "show" -> {
                showWindow()
                updateText(content)
                if (thinking.isNotEmpty()) {
                    updateThinkingText(thinking)
                }
            }
            "hide" -> hideWindow()
            "update" -> {
                updateText(content)
                if (thinking.isNotEmpty()) {
                    updateThinkingText(thinking)
                }
            }
            "updateThinking" -> updateThinkingText(content)
        }
        
        return START_STICKY
    }
    
    private fun createFloatingWindow() {
        // 获取屏幕宽度
        val displayMetrics = resources.displayMetrics
        val screenWidth = displayMetrics.widthPixels
        val windowWidth = (screenWidth * 0.85).toInt() // 85%屏幕宽度
        
        // 主容器 - 半透明黑色背景，大圆角
        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(32, 24, 32, 24)
            
            // 半透明黑色圆角背景
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#E6121212")) // 90%透明度黑色
                cornerRadius = 28f
            }
            
            layoutParams = LinearLayout.LayoutParams(
                windowWidth,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        }
        
        // 顶部：图标、标题和折叠按钮
        val headerLayout = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        }
        
        // AI图标
        val iconView = TextView(this).apply {
            text = "🤖"
            textSize = 20f
            setPadding(0, 0, 16, 0)
        }
        
        // 标题
        val titleView = TextView(this).apply {
            text = "AutoGLM"
            textSize = 16f
            setTextColor(Color.parseColor("#4CAF50"))
            setTypeface(null, Typeface.BOLD)
            layoutParams = LinearLayout.LayoutParams(
                0,
                LinearLayout.LayoutParams.WRAP_CONTENT,
                1f
            )
        }
        
        // 步骤标签
        stepTextView = TextView(this).apply {
            text = "步骤 1"
            textSize = 12f
            setTextColor(Color.parseColor("#888888"))
            setPadding(16, 0, 0, 0)
        }
        
        headerLayout.addView(iconView)
        headerLayout.addView(titleView)
        headerLayout.addView(stepTextView)
        
        // 分隔线
        val divider = View(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                1
            ).apply {
                topMargin = 16
                bottomMargin = 16
            }
            setBackgroundColor(Color.parseColor("#333333"))
        }
        
        // 思考区域标题
        val thinkingLabel = TextView(this).apply {
            text = "💭 思考"
            textSize = 12f
            setTextColor(Color.parseColor("#9E9E9E"))
            setPadding(0, 0, 0, 8)
        }
        
        // 思考内容 - 可滚动
        val thinkingScroll = ScrollView(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                200 // 固定高度，可滚动
            ).apply {
                bottomMargin = 16
            }
        }
        
        thinkingTextView = TextView(this).apply {
            text = "正在分析屏幕..."
            textSize = 13f
            setTextColor(Color.parseColor("#BDBDBD"))
            setLineSpacing(4f, 1.1f)
            setPadding(12, 12, 12, 12)
            
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#1A1A1A"))
                cornerRadius = 12f
            }
        }
        
        thinkingScroll.addView(thinkingTextView)
        
        // 动作区域标题
        val actionLabel = TextView(this).apply {
            text = "🎯 动作"
            textSize = 12f
            setTextColor(Color.parseColor("#9E9E9E"))
            setPadding(0, 0, 0, 8)
        }
        
        // 动作内容
        actionTextView = TextView(this).apply {
            text = "等待执行..."
            textSize = 15f
            setTextColor(Color.WHITE)
            setTypeface(null, Typeface.BOLD)
            setPadding(12, 12, 12, 12)
            
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#1B5E20"))
                cornerRadius = 12f
            }
        }
        
        // 添加所有视图
        container.addView(headerLayout)
        container.addView(divider)
        container.addView(thinkingLabel)
        container.addView(thinkingScroll)
        container.addView(actionLabel)
        container.addView(actionTextView)
        
        floatingView = container
        
        // 配置窗口参数
        layoutParams = WindowManager.LayoutParams().apply {
            width = windowWidth
            height = WindowManager.LayoutParams.WRAP_CONTENT
            x = (screenWidth - windowWidth) / 2
            y = 100
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
    
    fun updateThinkingText(thinking: String) {
        floatingView?.post {
            thinkingTextView?.text = thinking.ifEmpty { "正在分析..." }
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
