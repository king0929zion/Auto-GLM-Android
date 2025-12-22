package com.autoglm.auto_glm_mobile

import android.util.Base64
import android.util.Log
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import okio.ByteString
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

/**
 * 复用 Operit 的 Shower 控制逻辑：
 * - WebSocket 连接 ws://127.0.0.1:8986
 * - 发送 CREATE_DISPLAY / TAP / SWIPE / KEY / SCREENSHOT 等命令
 * - 接收 SCREENSHOT_DATA base64
 */
class ShowerController(
    private val host: String = "127.0.0.1",
    private val port: Int = 8986
) {
    private val client = OkHttpClient.Builder().build()

    @Volatile
    private var webSocket: WebSocket? = null

    @Volatile
    private var connected = false

    @Volatile
    private var virtualDisplayId: Int? = null

    @Volatile
    private var videoWidth: Int = 0

    @Volatile
    private var videoHeight: Int = 0

    private val pendingScreenshot = AtomicReference<CountDownLatch?>(null)
    private val screenshotData = AtomicReference<ByteArray?>(null)
    private val connectingLatch = AtomicReference<CountDownLatch?>(null)

    private val listener = object : WebSocketListener() {
        override fun onOpen(webSocket: WebSocket, response: Response) {
            connected = true
            connectingLatch.getAndSet(null)?.countDown()
            Log.d(TAG, "WebSocket connected to Shower server")
        }

        override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
            connected = false
            this@ShowerController.webSocket = null
            connectingLatch.getAndSet(null)?.countDown()
            pendingScreenshot.getAndSet(null)?.countDown()
            Log.d(TAG, "WebSocket closed: code=$code reason=$reason")
        }

        override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
            connected = false
            this@ShowerController.webSocket = null
            connectingLatch.getAndSet(null)?.countDown()
            pendingScreenshot.getAndSet(null)?.countDown()
            Log.e(TAG, "WebSocket failure", t)
        }

        override fun onMessage(webSocket: WebSocket, text: String) {
            if (text.startsWith("SCREENSHOT_DATA ")) {
                val base64 = text.substring("SCREENSHOT_DATA ".length).trim()
                screenshotData.set(
                    runCatching { Base64.decode(base64, Base64.DEFAULT) }.getOrNull()
                )
                pendingScreenshot.getAndSet(null)?.countDown()
                return
            } else if (text.startsWith("SCREENSHOT_ERROR")) {
                screenshotData.set(null)
                pendingScreenshot.getAndSet(null)?.countDown()
                return
            }

            val marker = "Virtual display id="
            val idx = text.indexOf(marker)
            if (idx >= 0) {
                val start = idx + marker.length
                val end = text.indexOfAny(charArrayOf(' ', ',', ';', '\n', '\r'), start)
                    .let { if (it == -1) text.length else it }
                val idStr = text.substring(start, end).trim()
                val id = idStr.toIntOrNull()
                if (id != null) {
                    virtualDisplayId = id
                    Log.d(TAG, "Discovered Shower virtual display id=$id")
                }
            }
        }

        override fun onMessage(webSocket: WebSocket, bytes: ByteString) {
            // H.264 视频流可在未来接入，这里暂不处理
        }
    }

    private fun buildUrl(): String = "ws://$host:$port"

    fun ensureConnected(timeoutMs: Long = 2000): Boolean {
        if (webSocket != null && connected) return true

        val existing = connectingLatch.get()
        if (existing != null) {
            return try {
                existing.await(timeoutMs, TimeUnit.MILLISECONDS) && connected
            } catch (_: InterruptedException) {
                false
            }
        }

        val latch = CountDownLatch(1)
        connectingLatch.set(latch)
        return try {
            val request = Request.Builder().url(buildUrl()).build()
            webSocket = client.newWebSocket(request, listener)
            latch.await(timeoutMs, TimeUnit.MILLISECONDS) && connected
        } catch (e: Exception) {
            Log.e(TAG, "Failed to connect WebSocket to Shower server", e)
            connectingLatch.set(null)
            false
        }
    }

    fun ensureDisplay(width: Int, height: Int, dpi: Int, bitrateKbps: Int? = null): Boolean {
        val ok = ensureConnected()
        if (!ok) return false

        sendText("DESTROY_DISPLAY")

        var alignedWidth = width and -8
        var alignedHeight = height and -8
        if (alignedWidth <= 0 || alignedHeight <= 0) {
            alignedWidth = maxOf(2, width)
            alignedHeight = maxOf(2, height)
        }

        videoWidth = alignedWidth
        videoHeight = alignedHeight

        val cmd = buildString {
            append("CREATE_DISPLAY ")
            append(alignedWidth)
            append(' ')
            append(alignedHeight)
            append(' ')
            append(dpi)
            if (bitrateKbps != null && bitrateKbps > 0) {
                append(' ')
                append(bitrateKbps)
            }
        }
        return sendText(cmd)
    }

    fun requestScreenshot(timeoutMs: Long = 3000): ByteArray? {
        val ok = ensureConnected()
        if (!ok) return null

        screenshotData.set(null)
        pendingScreenshot.getAndSet(null)?.countDown()
        val latch = CountDownLatch(1)
        pendingScreenshot.set(latch)

        if (!sendText("SCREENSHOT")) {
            pendingScreenshot.set(null)
            return null
        }

        return try {
            latch.await(timeoutMs, TimeUnit.MILLISECONDS)
            screenshotData.get()
        } catch (_: InterruptedException) {
            null
        } finally {
            pendingScreenshot.set(null)
        }
    }

    fun tap(x: Int, y: Int): Boolean = sendText("TAP $x $y")

    fun swipe(startX: Int, startY: Int, endX: Int, endY: Int, durationMs: Long = 300L): Boolean {
        return sendText("SWIPE $startX $startY $endX $endY $durationMs")
    }

    fun key(keyCode: Int): Boolean = sendText("KEY $keyCode")

    fun launchApp(packageName: String): Boolean {
        if (packageName.isBlank()) return false
        return sendText("LAUNCH_APP $packageName")
    }

    fun shutdown() {
        try {
            sendText("DESTROY_DISPLAY")
        } catch (_: Exception) {
        }
        try {
            webSocket?.close(1000, "shutdown")
        } catch (_: Exception) {
        } finally {
            webSocket = null
            connected = false
            virtualDisplayId = null
            videoWidth = 0
            videoHeight = 0
        }
    }

    private fun sendText(cmd: String): Boolean {
        val ws = webSocket ?: return false
        if (!connected) return false
        return try {
            ws.send(cmd)
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to send command: $cmd", e)
            false
        }
    }

    companion object {
        private const val TAG = "ShowerController"
    }
}
