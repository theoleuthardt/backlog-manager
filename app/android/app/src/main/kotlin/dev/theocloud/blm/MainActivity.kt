package dev.theocloud.blm

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * The activity of the app. It also answers `installApk` on the
 * `dev.theocloud.blm/update` channel, which hands a downloaded and verified
 * APK to the Android package installer: it answers `permission` (after
 * opening the settings page for it) while the app may not install apps yet,
 * otherwise it copies the APK to the folder [UpdateFileProvider] shares (on a
 * thread of its own, the file is tens of megabytes), opens the installer on it
 * and answers `started`. The copy of the last update is removed when the app
 * starts again. `dev.theocloud.blm/power` is [PowerSaveStreamHandler], whose
 * receiver goes with the engine.
 */
class MainActivity : FlutterFragmentActivity() {
    private var powerSave: PowerSaveStreamHandler? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        File(cacheDir, "updates").deleteRecursively()
        powerSave = PowerSaveStreamHandler(applicationContext).also {
            EventChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.theocloud.blm/power")
                .setStreamHandler(it)
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.theocloud.blm/update")
            .setMethodCallHandler { call, result ->
                val path = call.argument<String>("path")
                if (call.method != "installApk" || path == null) {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (!packageManager.canRequestPackageInstalls()) {
                    try {
                        openInstallSettings()
                        result.success("permission")
                    } catch (error: Exception) {
                        result.error("install-failed", error.message, null)
                    }
                    return@setMethodCallHandler
                }
                Thread {
                    try {
                        val apk = stageApk(File(path))
                        runOnUiThread {
                            try {
                                launchInstaller(apk)
                                result.success("started")
                            } catch (error: Exception) {
                                result.error("install-failed", error.message, null)
                            }
                        }
                    } catch (error: Exception) {
                        runOnUiThread { result.error("install-failed", error.message, null) }
                    }
                }.start()
            }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        powerSave?.onCancel(null)
        powerSave = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun openInstallSettings() {
        startActivity(
            Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:$packageName"),
            ),
        )
    }

    private fun stageApk(source: File): File {
        val folder = File(cacheDir, "updates").apply { mkdirs() }
        return source.copyTo(File(folder, "update.apk"), overwrite = true)
    }

    private fun launchInstaller(apk: File) {
        val uri = FileProvider.getUriForFile(this, "$packageName.updates", apk)
        startActivity(
            Intent(Intent.ACTION_VIEW)
                .setDataAndType(uri, "application/vnd.android.package-archive")
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION),
        )
    }
}
