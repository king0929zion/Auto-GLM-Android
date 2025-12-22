package com.autoglm.auto_glm_mobile

import android.content.Context
import android.util.Log
import rikka.shizuku.Shizuku
import java.io.BufferedReader
import java.io.InputStreamReader

object ShellCommandExecutor {
    private const val TAG = "ShellCommandExecutor"

    data class CommandResult(
        val success: Boolean,
        val stdout: String,
        val stderr: String = "",
        val exitCode: Int = -1
    )

    fun execute(command: String): CommandResult {
        if (!Shizuku.pingBinder() || Shizuku.checkSelfPermission() != android.content.pm.PackageManager.PERMISSION_GRANTED) {
            return CommandResult(false, "", "Shizuku not available", -1)
        }

        Log.d(TAG, "Executing via Shizuku: $command")

        // 1) Try Shizuku.newProcess
        try {
            val shizukuClass = Class.forName("rikka.shizuku.Shizuku")
            val newProcessMethod = shizukuClass.getDeclaredMethod(
                "newProcess",
                Array<String>::class.java,
                Array<String>::class.java,
                String::class.java
            )
            newProcessMethod.isAccessible = true

            val process = newProcessMethod.invoke(null, arrayOf("sh", "-c", command), null, null) as Process
            val stdout = process.inputStream.bufferedReader().readText()
            val stderr = process.errorStream.bufferedReader().readText()
            val exitCode = process.waitFor()
            return CommandResult(exitCode == 0, stdout, stderr, exitCode)
        } catch (e: Exception) {
            Log.w(TAG, "Shizuku.newProcess failed: ${e.message}")
        }

        // 2) Try ShizukuRemoteProcess
        try {
            val remoteProcessClass = Class.forName("rikka.shizuku.ShizukuRemoteProcess")
            val constructor = remoteProcessClass.getDeclaredConstructor(
                Array<String>::class.java,
                Array<String>::class.java,
                String::class.java
            )
            constructor.isAccessible = true

            val process = constructor.newInstance(arrayOf("sh", "-c", command), null, null) as Process
            val stdout = process.inputStream.bufferedReader().readText()
            val stderr = process.errorStream.bufferedReader().readText()
            val exitCode = process.waitFor()
            return CommandResult(exitCode == 0, stdout, stderr, exitCode)
        } catch (e: Exception) {
            Log.w(TAG, "ShizukuRemoteProcess failed: ${e.message}")
        }

        return CommandResult(false, "", "Shizuku command failed", -1)
    }
}
