package com.flutteriptv.flutter_iptv

import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.MethodChannel

/**
 * 原生日志工具类
 * 通过 MethodChannel 将原生日志发送到 Flutter 端的 LogService
 * 同时保留 logcat 输出用于开发调试
 */
object NativeLogger {
    private var methodChannel: MethodChannel? = null
    private var isInitialized = false
    private val mainHandler = Handler(Looper.getMainLooper())
    
    /**
     * 初始化日志通道
     * 在 MainActivity.configureFlutterEngine 中调用
     */
    fun init(channel: MethodChannel) {
        methodChannel = channel
        isInitialized = true
        Log.d("NativeLogger", "Native logger initialized")
    }
    
    /**
     * Debug 日志
     */
    fun d(tag: String, message: String) {
        // 输出到 logcat（开发调试用）
        Log.d(tag, message)
        
        // 发送到 Flutter 日志服务
        sendToFlutter("debug", tag, message)
    }
    
    /**
     * Info 日志
     */
    fun i(tag: String, message: String) {
        Log.i(tag, message)
        sendToFlutter("info", tag, message)
    }
    
    /**
     * Warning 日志
     */
    fun w(tag: String, message: String) {
        Log.w(tag, message)
        sendToFlutter("warning", tag, message)
    }
    
    /**
     * Error 日志
     */
    fun e(tag: String, message: String, error: Throwable? = null) {
        Log.e(tag, message, error)
        val errorMsg = if (error != null) {
            "$message\nError: ${error.message}\nStackTrace: ${error.stackTraceToString()}"
        } else {
            message
        }
        sendToFlutter("error", tag, errorMsg)
    }
    
    /**
     * 发送日志到 Flutter（在主线程执行）
     */
    private fun sendToFlutter(level: String, tag: String, message: String) {
        if (!isInitialized || methodChannel == null) {
            return
        }
        
        // 切换到主线程执行 MethodChannel 调用
        mainHandler.post {
            try {
                methodChannel?.invokeMethod("nativeLog", mapOf(
                    "level" to level,
                    "tag" to tag,
                    "message" to message
                ))
            } catch (e: Exception) {
                // 如果发送失败，只输出到 logcat，不抛出异常
                Log.w("NativeLogger", "Failed to send log to Flutter: ${e.message}")
            }
        }
    }
}
