package com.example.stocktok

import android.app.PictureInPictureParams
import android.os.Build
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import androidx.annotation.NonNull
import android.view.WindowManager
import android.util.Log

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.stocktok/pip"
    private var methodChannel: MethodChannel? = null
    private var isGoingToBackground = false
    private var isMainPage = false
    
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            Log.d("MainActivity", "Received method call: ${call.method}")
            when (call.method) {
                "enterPiP" -> {
                    Log.d("MainActivity", "Entering PiP mode via method channel")
                    if (isMainPage) {
                        enterPictureInPictureMode(PictureInPictureParams.Builder().build())
                        result.success(true)
                    } else {
                        result.error("NOT_MAIN_PAGE", "Cannot enter PiP when not on main page", null)
                    }
                }
                "setIsMainPage" -> {
                    val newValue = call.arguments as Boolean
                    Log.d("MainActivity", "Setting isMainPage from ${isMainPage} to ${newValue}")
                    isMainPage = newValue
                    result.success(true)
                }
                else -> {
                    Log.w("MainActivity", "Method not implemented: ${call.method}")
                    result.notImplemented()
                }
            }
        }
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        Log.d("MainActivity", "onUserLeaveHint called with isMainPage=$isMainPage")
        if (isMainPage) {
            isGoingToBackground = true
            try {
                enterPictureInPictureMode(PictureInPictureParams.Builder().build())
            } catch (e: Exception) {
                Log.e("MainActivity", "Failed to enter PiP mode: ${e.message}")
            }
        }
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode)
        Log.d("MainActivity", "PiP mode changed to: $isInPictureInPictureMode")
        methodChannel?.invokeMethod("onPiPChanged", isInPictureInPictureMode)
    }

    override fun onResume() {
        super.onResume()
        isGoingToBackground = false
    }
}
