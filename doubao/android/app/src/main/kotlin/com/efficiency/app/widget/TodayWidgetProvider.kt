package com.efficiency.app.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import com.efficiency.app.MainActivity
import com.efficiency.app.R
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/// 今日任务桌面小组件（4×2）
///
/// 读取 home_widget 写入的 HomeWidgetPreferences：
/// - widget_date：日期标题
/// - widget_done / widget_total：已完成 X / Y
/// - widget_task_1..3：前 3 条未完成标题
/// - widget_open_count：未完成条数（决定空态显隐）
/// 点击组件任意区域打开 App 主界面。
class TodayWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_today)

            // 点击组件打开主界面
            val launchIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
            )
            views.setOnClickPendingIntent(R.id.widget_container, launchIntent)

            val date = widgetData.getString("widget_date", null) ?: "今日任务"
            val done = widgetData.getInt("widget_done", 0)
            val total = widgetData.getInt("widget_total", 0)
            views.setTextViewText(R.id.widget_date, date)
            views.setTextViewText(R.id.widget_progress, "已完成 $done / $total")

            val taskViews: List<Pair<Int, String>> = listOf(
                Pair(R.id.widget_task_1, widgetData.getString("widget_task_1", "") ?: ""),
                Pair(R.id.widget_task_2, widgetData.getString("widget_task_2", "") ?: ""),
                Pair(R.id.widget_task_3, widgetData.getString("widget_task_3", "") ?: ""),
            )
            taskViews.forEach { pair ->
                val viewId = pair.first
                val title = pair.second
                if (title.isNotBlank()) {
                    views.setTextViewText(viewId, "· $title")
                    views.setViewVisibility(viewId, View.VISIBLE)
                } else {
                    views.setViewVisibility(viewId, View.GONE)
                }
            }

            val openCount = widgetData.getInt("widget_open_count", 0)
            views.setViewVisibility(
                R.id.widget_empty,
                if (openCount == 0) View.VISIBLE else View.GONE,
            )

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
