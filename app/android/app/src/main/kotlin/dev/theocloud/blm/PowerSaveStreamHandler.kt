package dev.theocloud.blm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.PowerManager
import io.flutter.plugin.common.EventChannel

/**
 * Sends on `dev.theocloud.blm/power` whether battery saver is on: the current
 * value when Dart starts to listen, then every change, so the app can lighten
 * its effects while the device saves power.
 */
class PowerSaveStreamHandler(private val context: Context) : EventChannel.StreamHandler {
    private var receiver: BroadcastReceiver? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        onCancel(null)
        val power = context.getSystemService(PowerManager::class.java)
        events.success(power.isPowerSaveMode)
        receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                events.success(power.isPowerSaveMode)
            }
        }.also {
            context.registerReceiver(it, IntentFilter(PowerManager.ACTION_POWER_SAVE_MODE_CHANGED))
        }
    }

    override fun onCancel(arguments: Any?) {
        receiver?.let { context.unregisterReceiver(it) }
        receiver = null
    }
}
