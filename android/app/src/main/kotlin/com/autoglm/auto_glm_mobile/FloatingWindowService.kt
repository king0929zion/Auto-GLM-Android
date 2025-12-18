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
    private var rootLayout: LinearLayout? = null
    private var ballContainer: FrameLayout? = null
    private var statusText: TextView? = null
    private var layoutParams: WindowManager.LayoutParams? = null
    
    // Eyes
    private var leftEye: View? = null
    private var rightEye: View? = null
    private var blinkHandler: Handler? = null
    private var blinkRunnable: Runnable? = null
    
    // Screen Info
    private var screenWidth = 0
    private var screenHeight = 0
    private var isOnRightSide = false
    
    // Takeover
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

        fun showTouchFeedback(x: Int, y: Int) {
            instance?.showFeedback(x, y)
        }
    }
    
    override fun onCreate() {
        super.onCreate()
        instance = this
        
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        val metrics = resources.displayMetrics
        screenWidth = metrics.widthPixels
        screenHeight = metrics.heightPixels
        
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
            "feedback" -> {
                val x = intent.getIntExtra("x", 0)
                val y = intent.getIntExtra("y", 0)
                showFeedback(x, y)
            }
        }
        
        return START_STICKY
    }
    
    private fun dp2px(dp: Float): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            dp,
            resources.displayMetrics
        ).toInt()
    }
    
    private fun createFloatingWindow() {
        // Root Container
        rootLayout = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            // Allows children to overlap if needed, but linear is fine
        }
        
        // 1. The Soot Sprite (Black Ball)
        val ballSize = dp2px(54f)
        ballContainer = FrameLayout(this).apply {
            layoutParams = LinearLayout.LayoutParams(ballSize, ballSize)
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.BLACK)
            }
            elevation = dp2px(8f).toFloat() // Keep shadow for the ball to make it pop (it's a sprite)
            // Add a subtle border
            foreground = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setStroke(dp2px(1f), Color.parseColor("#33FFFFFF"))
                setColor(Color.TRANSPARENT)
            }
        }
        
        // Eyes Layout
        val eyeWidth = dp2px(12f)
        val eyeHeight = dp2px(16f)
        val eyeTopMargin = dp2px(16f)
        val eyeHorizontalMargin = dp2px(10f)
        
        leftEye = View(this).apply {
            layoutParams = FrameLayout.LayoutParams(eyeWidth, eyeHeight).apply {
                gravity = Gravity.TOP or Gravity.START
                topMargin = eyeTopMargin
                marginStart = eyeHorizontalMargin
            }
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.WHITE)
            }
        }
        
        rightEye = View(this).apply {
            layoutParams = FrameLayout.LayoutParams(eyeWidth, eyeHeight).apply {
                gravity = Gravity.TOP or Gravity.END
                topMargin = eyeTopMargin
                marginEnd = eyeHorizontalMargin
            }
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.WHITE)
            }
        }
        
        ballContainer?.addView(leftEye)
        ballContainer?.addView(rightEye)
        
        // 2. Thinking Bubble (Refined for Exquisite Look)
        statusText = TextView(this).apply {
            text = ""
            textSize = 13f
            setTextColor(Color.BLACK)
            typeface = android.graphics.Typeface.DEFAULT_BOLD // Clean bold font
            background = GradientDrawable().apply {
                setColor(Color.WHITE)
                cornerRadius = dp2px(20f).toFloat() // Rounder, softer corners
                setStroke(dp2px(1f), Color.parseColor("#E0E0E0")) // Subtle definition
            }
            setPadding(dp2px(18f), dp2px(12f), dp2px(18f), dp2px(12f))
            elevation = dp2px(6f).toFloat() // Restored depth
            visibility = View.GONE
            
            // Layout params
            val params = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
            // Margins will be set dynamically based on side
            params.marginStart = dp2px(12f) // More spacing
            params.marginEnd = dp2px(12f)
            layoutParams = params
            maxWidth = dp2px(260f) // Slightly wider
        }
        
        // Initial assembly: Ball -> Bubble (Left side default)
        rootLayout?.addView(ballContainer)
        rootLayout?.addView(statusText)
        
        floatingView = rootLayout
        
        // Interaction: Tap to open app
        val openApp = View.OnClickListener {
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
        ballContainer?.setOnClickListener(openApp)
        
        // Window Parameters
        layoutParams = WindowManager.LayoutParams().apply {
            width = WindowManager.LayoutParams.WRAP_CONTENT
            height = WindowManager.LayoutParams.WRAP_CONTENT
            x = 0
            y = screenHeight / 4
            gravity = Gravity.TOP or Gravity.START
            
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
        
        // Drag Handling
        rootLayout?.setOnTouchListener(object : View.OnTouchListener {
            private var initialX = 0
            private var initialY = 0
            private var initialTouchX = 0f
            private var initialTouchY = 0f
            private var isMoving = false
            private val touchSlop = 10 // Px threshold
            
            override fun onTouch(v: View, event: MotionEvent): Boolean {
                when (event.action) {
                    MotionEvent.ACTION_DOWN -> {
                        initialX = layoutParams?.x ?: 0
                        initialY = layoutParams?.y ?: 0
                        initialTouchX = event.rawX
                        initialTouchY = event.rawY
                        isMoving = false
                        // Stop any ongoing specific animations if needed
                        return true
                    }
                    MotionEvent.ACTION_MOVE -> {
                        val dx = (event.rawX - initialTouchX).toInt()
                        val dy = (event.rawY - initialTouchY).toInt()
                        
                        // Check drag threshold
                        if (!isMoving && (Math.abs(dx) > touchSlop || Math.abs(dy) > touchSlop)) {
                            isMoving = true
                        }
                        
                        if (isMoving) {
                            layoutParams?.x = initialX + dx
                            layoutParams?.y = initialY + dy
                            
                            // Check which side we are on to update visuals immediately? 
                            // Or wait until snap. Let's wait until snap for smoother performance.
                            
                            try {
                                windowManager?.updateViewLayout(floatingView, layoutParams)
                            } catch (e: Exception) { }
                        }
                        return true
                    }
                    MotionEvent.ACTION_UP -> {
                        if (!isMoving) {
                            // Tap event
                            v.performClick()
                            ballContainer?.performClick()
                        } else {
                            // Snap to nearest edge
                            snapToEdge()
                        }
                        isMoving = false
                        return true
                    }
                }
                return false
            }
        })
        
        startBlinking()
        
        try {
            windowManager?.addView(floatingView, layoutParams)
            // Initial snap to left
            snapToEdge()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
    
    /**
     * Snap to Left or Right edge based on current position
     */
    private fun snapToEdge() {
        val currentX = layoutParams?.x ?: 0
        val viewWidth = floatingView?.width ?: 0
        val centerX = currentX + viewWidth / 2
        
        val targetX: Int
        val isRight: Boolean
        
        if (centerX > screenWidth / 2) {
            // Snap to Right
            targetX = screenWidth - viewWidth
            isRight = true
        } else {
            // Snap to Left
            targetX = 0
            isRight = false
        }
        
        isOnRightSide = isRight
        updateLayoutOrientation(isRight)
        
        // Animate movement
        val animator = android.animation.ValueAnimator.ofInt(currentX, targetX)
        animator.duration = 300
        animator.interpolator = android.view.animation.DecelerateInterpolator()
        animator.addUpdateListener { animation ->
            layoutParams?.x = animation.animatedValue as Int
            try {
                windowManager?.updateViewLayout(floatingView, layoutParams)
            } catch (e: Exception) {}
        }
        animator.start()
    }
    
    /**
     * Update Layout Order: 
     * Left Side: [Ball] [Bubble]
     * Right Side: [Bubble] [Ball]
     */
    private fun updateLayoutOrientation(isRight: Boolean) {
        rootLayout?.post {
            rootLayout?.removeAllViews()
            if (isRight) {
                // Device on Right Edge: [Text] [Ball]
                rootLayout?.addView(statusText)
                rootLayout?.addView(ballContainer)
            } else {
                // Device on Left Edge: [Ball] [Text]
                rootLayout?.addView(ballContainer)
                rootLayout?.addView(statusText)
            }
            updateBubbleBackground(isRight)
        }
    }

    private fun updateBubbleBackground(isRight: Boolean) {
        val r = dp2px(20f).toFloat()
        val sm = dp2px(4f).toFloat()
        
        val drawable = GradientDrawable().apply {
             setColor(Color.parseColor("#FCFFFFFF")) // High quality white
             setStroke(dp2px(1f), Color.parseColor("#E0E0E0"))
             
             // isRight means App is on Right Edge. Ball is on Right.
             // Layout: [Bubble] [Ball]
             // Bubble TopRight touches Ball
             if (isRight) {
                 // TopLeft, TopRight, BottomRight, BottomLeft
                 // TR is small
                 cornerRadii = floatArrayOf(r, r, sm, sm, r, r, r, r)
             } else {
                 // Layout: [Ball] [Bubble]
                 // Bubble TopLeft touches Ball
                 // TL is small
                 cornerRadii = floatArrayOf(sm, sm, r, r, r, r, r, r)
             }
        }
        statusText?.background = drawable
        // Ensure padding is maintained or reset if background replaces it?
        // Setting background might reset padding in some Android versions? 
        // Usually it does if drawable has padding. GradientDrawable doesn't.
        // But to be safe, we can re-set padding or just hope.
        // Let's re-set padding just in case.
        statusText?.setPadding(dp2px(18f), dp2px(12f), dp2px(18f), dp2px(12f))
        statusText?.elevation = dp2px(6f).toFloat()
    }
    
    private fun startBlinking() {
        if (blinkHandler == null) {
            blinkHandler = Handler(Looper.getMainLooper())
        }
        
        blinkRunnable = object : Runnable {
            override fun run() {
                // Random blink animation
                val closeDuration = 100L
                val openDuration = 150L
                
                leftEye?.animate()?.scaleY(0.1f)?.setDuration(closeDuration)?.withEndAction {
                    leftEye?.animate()?.scaleY(1.0f)?.setDuration(openDuration)?.start()
                }?.start()
                
                rightEye?.animate()?.scaleY(0.1f)?.setDuration(closeDuration)?.withEndAction {
                    rightEye?.animate()?.scaleY(1.0f)?.setDuration(openDuration)?.start()
                }?.start()
                
                // Random delay: 2s to 6s
                // Occasionally double blink handled by short delay? Simplify for now.
                val delay = (2000 + Math.random() * 4000).toLong()
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
     * Create Takeover Alert Window
     */
    private fun createTakeoverWindow() {
        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(48, 48, 48, 48)
            background = GradientDrawable().apply {
                setColor(Color.WHITE)
                cornerRadius = dp2px(24f).toFloat()
                setStroke(dp2px(1f), Color.parseColor("#E0E0E0")) // Border
            }
            elevation = 0f // Flat
        }
        
        val iconText = TextView(this).apply {
            text = "⚠️"
            textSize = 36f
            gravity = Gravity.CENTER
        }
        
        val titleText = TextView(this).apply {
            text = "Manual Intervention" // English for 'premium' feel? Or keep Chinese? User speaks Chinese.
            text = "需人工介入"
            textSize = 20f
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            setTextColor(Color.BLACK)
            gravity = Gravity.CENTER
            setPadding(0, 16, 0, 8)
        }
        
        takeoverMessageText = TextView(this).apply {
            text = "请完成操作后点击继续"
            textSize = 15f
            setTextColor(Color.parseColor("#666666")) // Grey 600
            gravity = Gravity.CENTER
            setPadding(0, 8, 0, 32)
            maxLines = 6
        }
        
        val continueButton = Button(this).apply {
            text = "完成并继续"
            textSize = 15f
            setTextColor(Color.WHITE)
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            background = GradientDrawable().apply {
                setColor(Color.BLACK) // Black button
                cornerRadius = dp2px(20f).toFloat() // Pill shape
            }
            elevation = 0f // No shadow
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, 
                dp2px(48f)
            )
            
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
            floatingView?.let { windowManager?.removeView(it) }
            floatingView = null
        } catch (e: Exception) { e.printStackTrace() }
    }
    
    private fun removeTakeoverWindow() {
        try {
            takeoverView?.let { windowManager?.removeView(it) }
            takeoverView = null
        } catch (e: Exception) { e.printStackTrace() }
    }
    
    // Typewriter
    private val typewriterHandler = Handler(Looper.getMainLooper())
    private var typewriterRunnable: Runnable? = null
    
    fun updateStatus(content: String) {
        floatingView?.post {
            // Cancel existing typewriter
            typewriterRunnable?.let { typewriterHandler.removeCallbacks(it) }
            
            if (content.isEmpty()) {
                if (statusText?.visibility == View.VISIBLE) {
                    statusText?.animate()?.alpha(0f)?.setDuration(200)?.withEndAction {
                        statusText?.visibility = View.GONE
                        statusText?.text = "" 
                        snapToEdge() 
                    }?.start()
                }
            } else {
                // If not visible, show it
                if (statusText?.visibility != View.VISIBLE) {
                    statusText?.alpha = 0f
                    statusText?.visibility = View.VISIBLE
                    statusText?.text = "" // Start empty
                    statusText?.animate()?.alpha(1f)?.setDuration(200)?.start()
                }
                
                // If content is same as current text (completed), do nothing
                if (statusText?.text.toString() == content) return@post
                
                // Calculate delay: faster for longer text
                val delay = if (content.length > 30) 15L else 30L
                
                var charIndex = 0
                statusText?.text = "" // Clear for typing
                
                typewriterRunnable = object : Runnable {
                    override fun run() {
                        if (charIndex < content.length) {
                            charIndex++
                            statusText?.text = content.substring(0, charIndex)
                            // Ideally, we should check if width change affects position here
                            typewriterHandler.postDelayed(this, delay)
                        } else {
                            // Finished
                            if (isOnRightSide) {
                                // Re-snap to ensure right-alignment consistency if width changed significantly
                                snapToEdge()
                            }
                        }
                    }
                }
                typewriterHandler.post(typewriterRunnable!!)
            }
        }
    }
    
    fun showWindow() {
        floatingView?.post {
            floatingView?.visibility = View.VISIBLE
            startBlinking()
            snapToEdge()
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

    /**
     * Show a visual feedback at coordinates (x, y)
     * "Not too deep" - Subtle ripple effect
     */
    fun showFeedback(x: Int, y: Int) {
        val size = dp2px(40f) // 40dp circle
        
        val feedbackView = View(this).apply {
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor("#40000000")) // 25% Black - Subtle
                setStroke(dp2px(2f), Color.parseColor("#80FFFFFF")) // 50% White rim
            }
        }
        
        val params = WindowManager.LayoutParams().apply {
            width = size
            height = size
            this.x = x - size / 2
            this.y = y - size / 2
            gravity = Gravity.TOP or Gravity.START
            
            type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            }
            
            flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
            
            format = PixelFormat.TRANSLUCENT
        }
        
        try {
            windowManager?.addView(feedbackView, params)
            
            // Animation: Scale Up & Fade Out
            feedbackView.animate()
                .scaleX(1.5f)
                .scaleY(1.5f)
                .alpha(0f)
                .setDuration(400)
                .withEndAction {
                    try {
                        windowManager?.removeView(feedbackView)
                    } catch (e: Exception) {}
                }
                .start()
                
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
