package com.autoglm.auto_glm_mobile

import android.util.Log
import org.java_websocket.client.WebSocketClient
import org.java_websocket.handshake.ServerHandshake
import java.net.URI
import java.nio.ByteBuffer
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

class ShowerWebSocketClient(serverUri: URI) {
    private val uri = serverUri
    private var client: WebSocketClient? = null
    @Volatile private var connected = false

    private val screenshotData = AtomicReference<String?>(null)
    @Volatile private var screenshotLatch: CountDownLatch? = null
    @Volatile private var videoWidth: Int = 0
    @Volatile private var videoHeight: Int = 0

    fun connect(timeoutMs: Long = 2000): Boolean {
        if (connected) return true

        val ws = object : WebSocketClient(uri) {
            override fun onOpen(handshakedata: ServerHandshake?) {
                connected = true
                Log.d("ShowerClient", "WebSocket connected")
            }

            override fun onMessage(message: String) {
                if (message.startsWith("SCREENSHOT_DATA ")) {
                    val data = message.removePrefix("SCREENSHOT_DATA ")
                    screenshotData.set(data)
                    screenshotLatch?.countDown()
                    return
                }
                if (message.startsWith("SCREENSHOT_ERROR")) {
                    screenshotData.set(null)
                    screenshotLatch?.countDown()
                }
            }

            override fun onMessage(bytes: ByteBuffer) {
                // ignore raw video stream
            }

            override fun onClose(code: Int, reason: String?, remote: Boolean) {
                connected = false
                Log.d("ShowerClient", "WebSocket closed: $code $reason")
            }

            override fun onError(ex: Exception?) {
                connected = false
                Log.e("ShowerClient", "WebSocket error", ex)
            }
        }

        client = ws
        return try {
            ws.connectBlocking(timeoutMs, TimeUnit.MILLISECONDS)
            connected
        } catch (e: Exception) {
            Log.e("ShowerClient", "connectBlocking failed", e)
            connected = false
            false
        }
    }

    fun isConnected(): Boolean = connected

    fun close() {
        try {
            client?.close()
        } catch (_: Exception) {
        }
        connected = false
        client = null
    }

    fun ensureConnected(timeoutMs: Long = 2000): Boolean {
        if (connected) return true
        return connect(timeoutMs)
    }

    fun ensureDisplay(width: Int, height: Int, dpi: Int, bitrateKbps: Int? = null): Boolean {
        if (!ensureConnected()) return false
        sendCommand("DESTROY_DISPLAY")

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
        return sendCommand(cmd)
    }

    fun destroyDisplay() {
        sendCommand("DESTROY_DISPLAY")
    }

    fun sendTap(x: Int, y: Int) {
        sendCommand("TAP $x $y")
    }

    fun sendSwipe(x1: Int, y1: Int, x2: Int, y2: Int, durationMs: Int) {
        sendCommand("SWIPE $x1 $y1 $x2 $y2 $durationMs")
    }

    fun sendKey(keyCode: Int) {
        sendCommand("KEY $keyCode")
    }

    fun launchApp(packageName: String) {
        sendCommand("LAUNCH_APP $packageName")
    }

    fun requestScreenshot(timeoutMs: Long = 2000): String? {
        if (!connected) return null
        screenshotData.set(null)
        val ws = client
        if (ws == null || !connected) return null

        val latch = CountDownLatch(1)
        screenshotLatch = latch
        sendCommand("SCREENSHOT")
        try {
            latch.await(timeoutMs, TimeUnit.MILLISECONDS)
        } catch (_: InterruptedException) {
        } finally {
            screenshotLatch = null
        }
        return screenshotData.get()
    }

    private fun sendCommand(command: String): Boolean {
        val ws = client ?: return false
        if (!connected) return false
        return try {
            ws.send(command)
            true
        } catch (e: Exception) {
            Log.e("ShowerClient", "sendCommand failed: $command", e)
            false
        }
    }
}
