package com.autoglm.auto_glm_mobile

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.inputmethodservice.InputMethodService
import android.os.Build
import android.util.Base64
import android.util.Log
import android.view.View
import android.view.inputmethod.EditorInfo
import android.widget.LinearLayout
import android.widget.TextView

/**
 * AutoZi 内置输入法
 * 用于通过 Shizuku 实现可靠的中文文本输入
 */
class AutoZiInputMethod : InputMethodService() {
    
    companion object {
        private const val TAG = "AutoZiInputMethod"
        
        // 广播 Actions
        const val ACTION_INPUT_TEXT = "com.autoglm.INPUT_TEXT"
        const val ACTION_INPUT_B64 = "com.autoglm.INPUT_B64"
        const val ACTION_CLEAR_TEXT = "com.autoglm.CLEAR_TEXT"
        
        // 广播 Extras
        const val EXTRA_TEXT = "text"
        const val EXTRA_MSG = "msg"
        
        // 输入法 ID
        const val IME_ID = "com.autoglm.auto_glm_mobile/.AutoZiInputMethod"
    }
    
    private var statusView: TextView? = null
    
    private val inputReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                ACTION_INPUT_TEXT -> {
                    val text = intent.getStringExtra(EXTRA_TEXT) ?: ""
                    Log.d(TAG, "Received INPUT_TEXT: $text")
                    commitText(text)
                }
                ACTION_INPUT_B64 -> {
                    val encodedText = intent.getStringExtra(EXTRA_MSG) ?: ""
                    Log.d(TAG, "Received INPUT_B64: $encodedText")
                    try {
                        val text = String(Base64.decode(encodedText, Base64.NO_WRAP), Charsets.UTF_8)
                        Log.d(TAG, "Decoded text: $text")
                        commitText(text)
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to decode base64: ${e.message}")
                    }
                }
                ACTION_CLEAR_TEXT -> {
                    Log.d(TAG, "Received CLEAR_TEXT")
                    clearText()
                }
            }
        }
    }
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "AutoZiInputMethod created")
        registerReceiver()
    }
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "AutoZiInputMethod destroyed")
        unregisterReceiver()
    }
    
    private fun registerReceiver() {
        val filter = IntentFilter().apply {
            addAction(ACTION_INPUT_TEXT)
            addAction(ACTION_INPUT_B64)
            addAction(ACTION_CLEAR_TEXT)
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(inputReceiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            registerReceiver(inputReceiver, filter)
        }
        Log.d(TAG, "Broadcast receiver registered")
    }
    
    private fun unregisterReceiver() {
        try {
            unregisterReceiver(inputReceiver)
            Log.d(TAG, "Broadcast receiver unregistered")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to unregister receiver: ${e.message}")
        }
    }
    
    override fun onCreateInputView(): View {
        // 创建一个简单的视图，显示 AutoZi 输入法状态
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(20, 10, 20, 10)
            setBackgroundColor(0xFF1E1E1E.toInt())
        }
        
        statusView = TextView(this).apply {
            text = "🤖 AutoZi 输入法已激活"
            setTextColor(0xFFFFFFFF.toInt())
            textSize = 14f
        }
        
        layout.addView(statusView)
        return layout
    }
    
    override fun onStartInputView(info: EditorInfo?, restarting: Boolean) {
        super.onStartInputView(info, restarting)
        Log.d(TAG, "onStartInputView - field: ${info?.fieldName}")
    }
    
    /**
     * 提交文本到当前输入框
     */
    private fun commitText(text: String) {
        val ic = currentInputConnection
        if (ic != null) {
            ic.commitText(text, 1)
            Log.d(TAG, "Text committed: $text")
            updateStatus("✓ 已输入: ${text.take(20)}${if (text.length > 20) "..." else ""}")
        } else {
            Log.e(TAG, "No input connection available")
            updateStatus("✗ 无法输入 - 无焦点")
        }
    }
    
    /**
     * 清除当前输入框的文本
     */
    private fun clearText() {
        val ic = currentInputConnection
        if (ic != null) {
            // 获取当前文本
            val beforeCursor = ic.getTextBeforeCursor(10000, 0) ?: ""
            val afterCursor = ic.getTextAfterCursor(10000, 0) ?: ""
            
            // 删除所有文本
            if (beforeCursor.isNotEmpty()) {
                ic.deleteSurroundingText(beforeCursor.length, 0)
            }
            if (afterCursor.isNotEmpty()) {
                ic.deleteSurroundingText(0, afterCursor.length)
            }
            
            Log.d(TAG, "Text cleared")
            updateStatus("✓ 已清除")
        } else {
            Log.e(TAG, "No input connection for clear")
        }
    }
    
    private fun updateStatus(status: String) {
        statusView?.post {
            statusView?.text = "🤖 AutoZi: $status"
        }
    }
}
