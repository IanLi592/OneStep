package com.onestep.onestep

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "onestep/widget"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method == "updateDueCount") {
                    val due = (call.argument<Number>("due") ?: 0).toInt()
                    updateWidget(due)
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }

    /// 把待复习数写入小组件读取的 SharedPreferences，并广播刷新。
    private fun updateWidget(due: Int) {
        val prefs = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        prefs.edit().putInt("onestep_due", due).apply()

        val intent = Intent(this, OnestepWidgetProvider::class.java)
        intent.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
        val ids = AppWidgetManager.getInstance(this)
            .getAppWidgetIds(ComponentName(this, OnestepWidgetProvider::class.java))
        intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
        sendBroadcast(intent)
    }
}
