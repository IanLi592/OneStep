package com.onestep.onestep

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews

/// 跬步桌面小组件：显示今日待复习卡片数（新卡 + 到期）。
///
/// 数据由 Flutter 侧通过 home_widget 写入 SharedPreferences（键 "onestep_due"），
/// 这里读取并刷新所有小组件实例。点按小组件打开应用。
class OnestepWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val dueCount = readDueCount(context)
        for (appWidgetId in appWidgetIds) {
            appWidgetManager.updateAppWidget(appWidgetId, buildViews(context, dueCount))
        }
    }

    override fun onReceive(context: Context, intent: android.content.Intent) {
        super.onReceive(context, intent)
        // home_widget 在数据变更时会发广播，触发重新读取并刷新。
        if (intent.action == ACTION_DUE_UPDATED) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                android.content.ComponentName(context, OnestepWidgetProvider::class.java),
            )
            onUpdate(context, manager, ids)
        }    }

    private fun readDueCount(context: Context): Int {
        val prefs: SharedPreferences = context.getSharedPreferences(
            "HomeWidgetPreferences",
            Context.MODE_PRIVATE,
        )
        return prefs.getInt("onestep_due", 0)
    }

    private fun buildViews(context: Context, dueCount: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.onestep_widget)
        views.setTextViewText(R.id.widget_due, "$dueCount")
        val label = if (dueCount > 0) "今日待复习" else "今日已清空 ✓"
        views.setTextViewText(R.id.widget_label, label)
        // 点按打开应用。
        val launchIntent = context.packageManager
            .getLaunchIntentForPackage(context.packageName)
        if (launchIntent != null) {
            views.setOnClickPendingIntent(
                R.id.widget_root,
                android.app.PendingIntent.getActivity(
                    context,
                    0,
                    launchIntent,
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or
                        android.app.PendingIntent.FLAG_IMMUTABLE,
                ),
            )
        }
        return views
    }

    companion object {
        const val ACTION_DUE_UPDATED = "com.onestep.onestep.DUE_UPDATED"
    }
}
