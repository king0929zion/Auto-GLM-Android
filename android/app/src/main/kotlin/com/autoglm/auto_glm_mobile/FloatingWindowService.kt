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
import android.widget.FrameLayout
import android.os.Handler
import android.os.Looper
import android.util.TypedValue

/**
 * 悬浮窗服务
 * 1. 运行指示器 - 小型胶囊状
 * 2. Takeover弹窗 - 大型提示框
 */
class FloatingWindowService : Service() {
    
    private var windowManager: WindowManager? = null
    private var floatingView: View? = null
    private var statusText: TextView? = null
    private var layoutParams: WindowManager.LayoutParams? = null
    
    // Eyes
    private var leftEye: View? = null
    private var rightEye: View? = null
    private var blinkHandler: android.os.Handler? = null
    private var blinkRunnable: Runnable? = null
    
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
        stopBlinking()
        removeFloatingWindow()
        removeTakeoverWindow()
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.getStringExtra("action")
        val content = intent?.getStringExtra("content") ?: ""
        
        when (action) {
            "show" -> {
                showWindow()
                if (content.isNotEmpty()) updateStatus(content)
            }
            "hide" -> hideWindow()
            "update" -> updateStatus(content)
            "takeover" -> showTakeoverAlert(content)
            "hideTakeover" -> hideTakeoverAlert()
        }
        
        return START_STICKY
    }
    
    private fun dp2px(dp: Float): Int {
        return android.util.TypedValue.applyDimension(
            android.util.TypedValue.COMPLEX_UNIT_DIP,
            dp,
            resources.displayMetrics
        ).toInt()
    }
    
    private fun createFloatingWindow() {
        // 主容器
        val rootLayout = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            // 不设置背景，保持透明
        }
        
        // 1. 黑球容器
        val ballSize = dp2px(50f)
        val ballContainer = android.widget.FrameLayout(this).apply {
            layoutParams = LinearLayout.LayoutParams(ballSize, ballSize)
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.BLACK)
            }
            elevation = dp2px(4f).toFloat()
        }
        
        // 眼睛参数
        val eyeWidth = dp2px(10f)
        val eyeHeight = dp2px(14f)
        val eyeTopMargin = dp2px(15f)
        
        // 左眼
        leftEye = View(this).apply {
            layoutParams = android.widget.FrameLayout.LayoutParams(eyeWidth, eyeHeight).apply {
                gravity = Gravity.TOP or Gravity.START
                topMargin = eyeTopMargin
                marginStart = dp2px(12f)
            }
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.WHITE)
            }
        }
        
        // 右眼
        rightEye = View(this).apply {
            layoutParams = android.widget.FrameLayout.LayoutParams(eyeWidth, eyeHeight).apply {
                gravity = Gravity.TOP or Gravity.END
                topMargin = eyeTopMargin
                marginEnd = dp2px(12f)
            }
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.WHITE)
            }
        }
        
        ballContainer.addView(leftEye)
        ballContainer.addView(rightEye)
        
        // 2. 思考气泡 (状态文字)
        statusText = TextView(this).apply {
            text = "Ready"
            textSize = 13f
            setTextColor(Color.BLACK)
            background = GradientDrawable().apply {
                setColor(Color.WHITE)
                cornerRadius = dp2px(12f).toFloat()
                setStroke(dp2px(1f), Color.parseColor("#E0E0E0"))
            }
            setPadding(dp2px(12f), dp2px(8f), dp2px(12f), dp2px(8f))
            visibility = View.GONE // 初始隐藏，有内容时显示
            
            val params = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
            params.marginStart = dp2px(12f)
            layoutParams = params
            maxWidth = dp2px(220f) // 限制最大宽度
        }
        
        rootLayout.addView(ballContainer)
        rootLayout.addView(statusText)
        
        floatingView = rootLayout
        
        // 点击返回 App
        ballContainer.setOnClickListener {
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
        
        // 配置窗口参数
        layoutParams = WindowManager.LayoutParams().apply {
            width = WindowManager.LayoutParams.WRAP_CONTENT
            height = WindowManager.LayoutParams.WRAP_CONTENT
            x = 0
            y = 100
            gravity = Gravity.TOP or Gravity.START // 改为左上角开始，方便拖拽
            
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
        
        // 添加拖动功能 (只在黑球上响应拖动，避免气泡遮挡操作？或者整体拖动)
        // 这里设置为整体拖动
        rootLayout.setOnTouchListener(object : View.OnTouchListener {
            private var initialX = 0
            private var initialY = 0
            private var initialTouchX = 0f
            private var initialTouchY = 0f
            private var isMoving = false
            
            override fun onTouch(v: View, event: MotionEvent): Boolean {
                when (event.action) {
                    MotionEvent.ACTION_DOWN -> {
                        initialX = layoutParams?.x ?: 0
                        initialY = layoutParams?.y ?: 0
                        initialTouchX = event.rawX
                        initialTouchY = event.rawY
                        isMoving = false
                        return true // 消费事件
                    }
                    MotionEvent.ACTION_MOVE -> {
                        val dx = (event.rawX - initialTouchX).toInt()
                        val dy = (event.rawY - initialTouchY).toInt()
                        
                        // 判定为移动
                        if (Math.abs(dx) > 10 || Math.abs(dy) > 10) {
                            isMoving = true
                            layoutParams?.x = initialX + dx
                            layoutParams?.y = initialY + dy
                            try {
                                windowManager?.updateViewLayout(floatingView, layoutParams)
                            } catch (e: Exception) {
                                // Ignore
                            }
                        }
                        return true
                    }
                    MotionEvent.ACTION_UP -> {
                        if (!isMoving) {
                            // 如果不是移动，由于我们拦截了Touch，需要手动触发Click
                            // 检测是否点击在球上? 简单起见，如果点击了就触发App跳转
                            v.performClick()
                            ballContainer.performClick()
                        }
                        return true
                    }
                }
                return false
            }
        })
        
        startBlinking()
        
        try {
            windowManager?.addView(floatingView, layoutParams)
            floatingView?.visibility = View.GONE
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
    
    private fun startBlinking() {
        blinkHandler = android.os.Handler(android.os.Looper.getMainLooper())
        blinkRunnable = object : Runnable {
            override fun run() {
                // 眨眼动画：缩放Y轴
                val closeDuration = 150L
                val openDuration = 150L
                
                leftEye?.animate()?.scaleY(0.1f)?.setDuration(closeDuration)?.withEndAction {
                    leftEye?.animate()?.scaleY(1.0f)?.setDuration(openDuration)?.start()
                }?.start()
                
                rightEye?.animate()?.scaleY(0.1f)?.setDuration(closeDuration)?.withEndAction {
                    rightEye?.animate()?.scaleY(1.0f)?.setDuration(openDuration)?.start()
                }?.start()
                
                // 随机下次眨眼时间 (2-5秒)
                val delay = (2000 + Math.random() * 3000).toLong()
                blinkHandler?.postDelayed(this, delay)
            }
        }
        blinkHandler?.post(blinkRunnable!!)
    }
    
    private fun stopBlinking() {
        blinkRunnable?.let { blinkHandler?.removeCallbacks(it) }
        blinkHandler = null
    }

    /**
     * 创建Takeover弹窗
     */
    private fun createTakeoverWindow() {
        val displayMetrics = resources.displayMetrics
        val screenWidth = displayMetrics.widthPixels
        
        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(48, 40, 48, 40)
            
            background = GradientDrawable().apply {
                setColor(Color.WHITE) // 改为白色背景
                cornerRadius = 32f
            }
            elevation = dp2px(8f).toFloat()
        }
        
        // 警告图标
        val iconText = TextView(this).apply {
            text = "⚠️"
            textSize = 40f
            gravity = Gravity.CENTER
        }
        
        // 标题
        val titleText = TextView(this).apply {
            text = "需要人工接管"
            textSize = 20f
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            setTextColor(Color.BLACK)
            gravity = Gravity.CENTER
            setPadding(0, 16, 0, 8)
        }
        
        // 消息内容
        takeoverMessageText = TextView(this).apply {
            text = "请完成操作后点击继续"
            textSize = 15f
            setTextColor(Color.parseColor("#666666"))
            gravity = Gravity.CENTER
            setPadding(0, 8, 0, 24)
            maxLines = 5
        }
        
        // 继续按钮
        val continueButton = Button(this).apply {
            text = "已完成，继续"
            textSize = 16f
            setTextColor(Color.WHITE)
            background = GradientDrawable().apply {
                setColor(Color.BLACK)
                cornerRadius = 24f
            }
            setPadding(48, 0, 48, 0)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, 
                dp2px(48f)
            ).apply {
                topMargin = dp2px(16f)
            }
            
            setOnClickListener {
                hideTakeoverAlert()
            }
        }
        
        container.addView(iconText)
        container.addView(titleText)
        container.addView(takeoverMessageText)
        container.addView(continueButton)
        
        takeoverView = container
        
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
    
    private fun removeFloatingWindow() {
        try {
            stopBlinking()
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
            if (content.isEmpty()) {
                statusText?.visibility = View.GONE
            } else {
                statusText?.text = content
                statusText?.visibility = View.VISIBLE
            }
        }
    }
    
    fun showWindow() {
        floatingView?.post {
            floatingView?.visibility = View.VISIBLE
            // 重置位置到左上或记忆位置 (这里暂不重置，保留上次位置)
            startBlinking()
        }
    }
    
    fun hideWindow() {
        floatingView?.post {
            stopBlinking()
            floatingView?.visibility = View.GONE
        }
    }
    
    fun showTakeoverAlert(message: String) {
        takeoverView?.post {
            takeoverMessageText?.text = message
            takeoverView?.visibility = View.VISIBLE
            floatingView?.visibility = View.GONE
        }
    }
    
    fun hideTakeoverAlert() {
        takeoverView?.post {
            takeoverView?.visibility = View.GONE
            floatingView?.visibility = View.VISIBLE
            startBlinking()
        }
    }
}
