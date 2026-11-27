package com.harukoto.app

import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.harukoto.app/app_version")
            .setMethodCallHandler { call, result ->
                if (call.method != "getVersion") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                try {
                    result.success(readInstalledVersion())
                } catch (error: PackageManager.NameNotFoundException) {
                    result.error("VERSION_UNAVAILABLE", null, null)
                }
            }
    }

    @Suppress("DEPRECATION")
    private fun readInstalledVersion(): Map<String, String?> {
        val info = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.getPackageInfo(packageName, PackageManager.PackageInfoFlags.of(0))
        } else {
            packageManager.getPackageInfo(packageName, 0)
        }
        val build = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode
        } else {
            info.versionCode.toLong()
        }
        return mapOf("version" to info.versionName, "buildNumber" to build.toString())
    }
}
