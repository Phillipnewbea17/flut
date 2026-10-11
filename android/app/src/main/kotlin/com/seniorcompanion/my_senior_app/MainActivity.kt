package com.seniorcompanion.my_senior_app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // SOS: start the call right away, without the extra tap in the
        // dialer. Returns false when the phone permission is not given, so
        // the app opens the dialer instead.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "senior_companion/sos")
            .setMethodCallHandler { call, result ->
                if (call.method != "callNow") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val number = call.argument<String>("number")
                if (number.isNullOrBlank() ||
                    checkSelfPermission(Manifest.permission.CALL_PHONE) !=
                    PackageManager.PERMISSION_GRANTED
                ) {
                    result.success(false)
                    return@setMethodCallHandler
                }
                try {
                    startActivity(Intent(Intent.ACTION_CALL, Uri.parse("tel:$number")))
                    result.success(true)
                } catch (e: Exception) {
                    result.success(false)
                }
            }
    }
}
