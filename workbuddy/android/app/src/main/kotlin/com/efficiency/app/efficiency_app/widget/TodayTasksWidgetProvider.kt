package com.efficiency.app.efficiency_app.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import com.efficiency.app.efficiency_app.MainActivity
import com.efficiency.app.efficiency_app.R
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * 「今日任务」桌面小组件（4x2）。
 *
 * 职责边界：**只做排版**。数据由 Flutter 侧算好后写进
 * `HomeWidgetPreferences`（键名见 `lib/features/widget/data/today_widget_sync.dart`
 * 里的 `TodayWidgetKeys`，两边逐字对应，改名必须同时改）。
 *
 * 为什么不在原生侧读数据库：
 * 1. 小组件在**桌面进程**的渲染路径里执行，那里没有 Drift、没有迁移逻辑；
 * 2. `onUpdate` 有 10 秒左右的执行窗口，一次 refresh 去开 SQLite 连接不划算；
 * 3. 统计口径（哪些算「今天」、已删除怎么算）只该有一份实现。
 *
 * 继承 `HomeWidgetProvider`（插件提供的抽象类）而不是裸 `AppWidgetProvider`：
 * 它替我们把 SharedPreferences 取好传进来，并处理了「计划刷新」的重建逻辑。
 */
class TodayTasksWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (appWidgetId in appWidgetIds) {
            appWidgetManager.updateAppWidget(appWidgetId, buildViews(context, widgetData))
        }
    }

    private fun buildViews(context: Context, data: SharedPreferences): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.today_tasks_widget)

        val dateLabel = data.getString(KEY_DATE, "").orEmpty()
        val done = data.getInt(KEY_DONE, 0)
        val total = data.getInt(KEY_TOTAL, 0)
        val remaining = data.getInt(KEY_REMAINING, 0)
        val emptyLabel = data.getString(KEY_EMPTY_LABEL, "").orEmpty()

        // ---- 日期 --------------------------------------------------------
        views.setTextViewText(
            R.id.widget_date,
            dateLabel.ifBlank { context.getString(R.string.widget_title) },
        )

        // ---- 进度 --------------------------------------------------------
        // 这里刻意用「已完成 X / Y」而不是百分比：任务量小的时候（3/5）
        // 百分比会把「还差几条」这层信息抹掉。
        views.setTextViewText(R.id.widget_progress, "已完成 $done / $total")
        val percent = if (total <= 0) 0 else (done * 100 / total)
        views.setProgressBar(R.id.widget_bar, 100, percent, false)

        // ---- 三条未完成任务 ----------------------------------------------
        val taskIds = intArrayOf(R.id.widget_task_1, R.id.widget_task_2, R.id.widget_task_3)
        taskIds.forEachIndexed { index, viewId ->
            val title = data.getString(taskKey(index), "").orEmpty()
            if (title.isBlank()) {
                views.setViewVisibility(viewId, View.GONE)
            } else {
                views.setViewVisibility(viewId, View.VISIBLE)
                views.setTextViewText(viewId, title)
            }
        }

        // ---- 空态 --------------------------------------------------------
        // 三种情况：正常有任务（隐藏空态）/ 今天没有任务或全部完成（显示 Dart 给的文案）
        // / App 从未运行过、prefs 里空无一物（给一句「打开应用同步」的提示，
        // 否则用户看到的是一个只剩标题的空壳，会以为小组件坏了）。
        val anyTask = (0 until TASK_SLOTS).any { !data.getString(taskKey(it), "").isNullOrBlank() }
        when {
            anyTask -> views.setViewVisibility(R.id.widget_empty, View.GONE)
            dateLabel.isBlank() -> {
                views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
                views.setTextViewText(R.id.widget_empty, "打开应用完成首次同步")
            }
            else -> {
                views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
                views.setTextViewText(
                    R.id.widget_empty,
                    emptyLabel.ifBlank { "今天的任务都完成了" },
                )
            }
        }

        // 有未完成但只显示了 3 条时，补一句「还有 N 条」——否则用户会以为清单只有这些。
        if (remaining > TASK_SLOTS) {
            views.setTextViewText(
                R.id.widget_progress,
                "已完成 $done / $total · 还有 ${remaining - TASK_SLOTS} 条",
            )
        }

        // ---- 点击任意位置 → 打开应用 --------------------------------------
        views.setOnClickPendingIntent(R.id.widget_root, launchApp(context))
        return views
    }

    private fun launchApp(context: Context): PendingIntent {
        // 走 LAUNCHER 语义的 Intent：若应用在后台，回到原来的任务栈；
        // 没有则新开。比 `Intent(context, MainActivity::class.java)` 裸启动更符合
        // 「点桌面图标」的预期（不会把已有页面顶掉重建）。
        val intent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_MAIN
            addCategory(Intent.CATEGORY_LAUNCHER)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            context,
            REQUEST_LAUNCH,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun taskKey(index: Int): String = "today_task_${index + 1}"

    companion object {
        /** 小组件能显示的任务条数（4x2 的高度上限，与 Dart 侧 maxPending 一致）。 */
        private const val TASK_SLOTS = 3

        private const val REQUEST_LAUNCH = 1001

        // ---- 与 TodayWidgetKeys 逐字对应 ----
        private const val KEY_DATE = "today_date"
        private const val KEY_DONE = "today_done"
        private const val KEY_TOTAL = "today_total"
        private const val KEY_REMAINING = "today_remaining"
        private const val KEY_EMPTY_LABEL = "today_empty_label"
    }
}
