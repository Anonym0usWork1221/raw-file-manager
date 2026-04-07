package com.jara.manager.raw_file_manager

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    // 保持通道名称不变
    private val CHANNEL = "com.jara.manager.raw_file_manager/apk_install"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "installApk") {
                val apkPath = call.argument<String>("apkPath")
                
                // 1. 校验路径
                if (apkPath.isNullOrEmpty()) {
                    // 修复类型：明确指定Map<String, Any>
                    result.success(mapOf<String, Any>(
                        "success" to false,
                        "message" to "APK文件路径为空"
                    ))
                    return@setMethodCallHandler
                }

                // 2. 仅执行调起安装弹窗的核心逻辑
                val (success, message) = launchInstallDialog(apkPath)
                
                // 修复类型：明确指定Map<String, Any>
                result.success(mapOf<String, Any>(
                    "success" to success,
                    "message" to message
                ))
            } else {
                result.notImplemented()
            }
        }
    }

    // 核心：仅调起系统安装弹窗（去掉所有权限申请逻辑）
    private fun launchInstallDialog(apkPath: String): Pair<Boolean, String> {
        val file = File(apkPath)
        
        // 基础校验
        if (!file.exists()) {
            return Pair(false, "APK文件不存在：$apkPath")
        }
        
        if (!apkPath.endsWith(".apk", ignoreCase = true)) {
            return Pair(false, "文件不是APK格式")
        }

        try {
            val intent = Intent(Intent.ACTION_VIEW)
            val uri: Uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                // 必须和AndroidManifest中的fileProvider一致
                FileProvider.getUriForFile(
                    this,
                    "$packageName.fileProvider",
                    file
                )
            } else {
                Uri.fromFile(file)
            }

            intent.setDataAndType(uri, "application/vnd.android.package-archive")
            // 关键Flags：必须加，否则调不起安装弹窗
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION
            
            // 检查是否有应用能处理安装Intent
            if (intent.resolveActivity(packageManager) == null) {
                return Pair(false, "无可用的APK安装应用")
            }

            // 调起系统安装弹窗（核心功能）
            startActivity(intent)
            return Pair(true, "已调起系统安装弹窗")
        } catch (e: Exception) {
            return Pair(false, "调起安装弹窗失败：${e.message ?: "未知错误"}")
        }
    }
}
