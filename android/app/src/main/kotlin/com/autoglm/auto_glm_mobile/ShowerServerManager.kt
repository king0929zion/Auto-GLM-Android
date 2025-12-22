package com.autoglm.auto_glm_mobile

import android.content.Context
import android.os.Environment
import android.util.Log
import java.io.File
import java.io.FileOutputStream
import java.net.InetSocketAddress
import java.net.Socket

object ShowerServerManager {
    private const val TAG = "ShowerServerManager"
    private const val ASSET_JAR_NAME = "shower-server.jar"
    private const val LOCAL_JAR_NAME = "shower-server.jar"
    private const val SERVER_PORT = 8986

    data class StartResult(val success: Boolean, val error: String? = null)

    fun ensureServerStarted(context: Context): StartResult {
        if (isServerListening()) {
            return StartResult(true)
        }

        val appContext = context.applicationContext
        val jarFile = try {
            copyJarToExternalDir(appContext)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to copy shower-server.jar", e)
            return StartResult(false, e.message)
        }

        val killCmd = "pkill -f com.ai.assistance.shower.Main >/dev/null 2>&1 || true"
        ShellCommandExecutor.execute(killCmd)

        val remoteJarPath = "/data/local/tmp/$LOCAL_JAR_NAME"
        val copyCmd = "cp ${jarFile.absolutePath} $remoteJarPath"
        val copyResult = ShellCommandExecutor.execute(copyCmd)
        if (!copyResult.success) {
            return StartResult(false, "copy jar failed: ${copyResult.stderr}")
        }

        val startCmd = "CLASSPATH=$remoteJarPath app_process / com.ai.assistance.shower.Main &"
        val startResult = ShellCommandExecutor.execute(startCmd)
        if (!startResult.success) {
            return StartResult(false, "start server failed: ${startResult.stderr}")
        }

        for (attempt in 0 until 50) {
            Thread.sleep(200)
            if (isServerListening()) {
                return StartResult(true)
            }
        }

        return StartResult(false, "server not responding on 127.0.0.1:$SERVER_PORT")
    }

    fun stopServer(): Boolean {
        val cmd = "pkill -f com.ai.assistance.shower.Main >/dev/null 2>&1 || true"
        return ShellCommandExecutor.execute(cmd).success
    }

    private fun copyJarToExternalDir(context: Context): File {
        val baseDir = context.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
            ?: context.getExternalFilesDir(null)
            ?: context.filesDir
        if (!baseDir.exists()) {
            baseDir.mkdirs()
        }
        val outFile = File(baseDir, LOCAL_JAR_NAME)
        context.assets.open(ASSET_JAR_NAME).use { input ->
            FileOutputStream(outFile).use { output ->
                val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                while (true) {
                    val read = input.read(buffer)
                    if (read <= 0) break
                    output.write(buffer, 0, read)
                }
                output.flush()
            }
        }
        Log.d(TAG, "Copied $ASSET_JAR_NAME to ${outFile.absolutePath}")
        return outFile
    }

    private fun isServerListening(): Boolean {
        return try {
            Socket().use { socket ->
                socket.connect(InetSocketAddress("127.0.0.1", SERVER_PORT), 200)
            }
            true
        } catch (e: Exception) {
            false
        }
    }
}
