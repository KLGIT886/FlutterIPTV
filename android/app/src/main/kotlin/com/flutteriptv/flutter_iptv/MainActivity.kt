package com.flutteriptv.flutter_iptv

import android.content.res.Configuration
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.flutteriptv/platform"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isTV" -> {
                    result.success(isAndroidTV())
                }
                "getDeviceType" -> {
                    result.success(getDeviceType())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    private fun isAndroidTV(): Boolean {
        val uiModeManager = getSystemService(UI_MODE_SERVICE) as android.app.UiModeManager
        return uiModeManager.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION
    }
    
    private fun getDeviceType(): String {
        return when {
            isAndroidTV() -> "tv"
            isTablet() -> "tablet"
            else -> "phone"
        }
    }
    
    private fun isTablet(): Boolean {
        val screenLayout = resources.configuration.screenLayout
        val screenSize = screenLayout and Configuration.SCREENLAYOUT_SIZE_MASK
        return screenSize >= Configuration.SCREENLAYOUT_SIZE_LARGE
    }
}
