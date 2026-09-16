package com.example.noor_prayer_tasbeeh

import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "noor.app/update",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "installApk" -> {
                    val apkPath = call.argument<String>("apkPath")

                    if (apkPath.isNullOrBlank()) {
                        result.error(
                            "INVALID_APK_PATH",
                            "APK path is missing.",
                            null,
                        )
                    } else {
                        try {
                            val apkFile = java.io.File(apkPath)

                            if (!apkFile.exists()) {
                                result.error(
                                    "APK_NOT_FOUND",
                                    "APK file was not found.",
                                    null,
                                )
                                return@setMethodCallHandler
                            }

                            val apkUri = FileProvider.getUriForFile(
                                this,
                                "com.example.noor_prayer_tasbeeh.fileprovider",
                                apkFile,
                            )

                            val intent = Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(
                                    apkUri,
                                    "application/vnd.android.package-archive",
                                )
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }

                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error(
                                "INSTALL_FAILED",
                                e.message,
                                null,
                            )
                        }
                    }
                }

                else -> result.notImplemented()
            }
        }
    }
}
