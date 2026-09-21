package dev.beetlebyte.cairn

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.net.Uri
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin

class CairnTasksWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            render(context, appWidgetManager, appWidgetId, null)
        }
    }

    /** A resize changes how many rows fit, so re-render rather than leave gaps. */
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        render(context, appWidgetManager, appWidgetId, newOptions)
    }

    private fun render(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        options: Bundle?
    ) {
        val widgetData = HomeWidgetPlugin.getData(context)
        val views = RemoteViews(context.packageName, R.layout.cairn_tasks_widget).apply {
            val summary = widgetData.getString("tasks_summary", "All clear") ?: "All clear"
            val totalCount = widgetData.getInt("tasks_total_count", 0)

            setTextViewText(R.id.tasks_summary, summary)

            val rowIds = arrayOf(
                R.id.task_row_1, R.id.task_row_2, R.id.task_row_3,
                R.id.task_row_4, R.id.task_row_5
            )
            val checkIds = arrayOf(
                R.id.task_1_check, R.id.task_2_check, R.id.task_3_check,
                R.id.task_4_check, R.id.task_5_check
            )
            val titleIds = arrayOf(
                R.id.task_1_title, R.id.task_2_title, R.id.task_3_title,
                R.id.task_4_title, R.id.task_5_title
            )
            val priorityIds = arrayOf(
                R.id.task_1_priority, R.id.task_2_priority, R.id.task_3_priority,
                R.id.task_4_priority, R.id.task_5_priority
            )

            val rowCap = WidgetRowSizing.rowsThatFit(
                appWidgetManager,
                appWidgetId,
                WidgetRowSizing.TASKS_CHROME_DP,
                rowIds.size,
                options
            )

            var visibleRows = 0
            for (i in rowIds.indices) {
                val taskTitle = widgetData.getString("task_${i + 1}_title", null)
                val taskId = widgetData.getString("task_${i + 1}_id", null)
                if (taskTitle != null && i < rowCap) {
                    // 1 is the highest priority; 4 is the app's "none" default.
                    val priority = widgetData.getInt("task_${i + 1}_priority", 4)

                    setViewVisibility(rowIds[i], View.VISIBLE)
                    setTextViewText(titleIds[i], taskTitle)

                    if (priority in 1..3) {
                        setViewVisibility(priorityIds[i], View.VISIBLE)
                        setTextViewText(priorityIds[i], "P$priority")
                        // Only P1 takes the accent, so the most urgent row is
                        // the one that draws the eye; P2/P3 stay muted.
                        val priorityColor = if (priority == 1) {
                            R.color.widget_accent
                        } else {
                            R.color.widget_text_muted
                        }
                        setTextColor(priorityIds[i], context.getColor(priorityColor))
                    } else {
                        setViewVisibility(priorityIds[i], View.GONE)
                    }

                    if (taskId != null) {
                        val toggleIntent = HomeWidgetBackgroundIntent.getBroadcast(
                            context,
                            Uri.parse("cairn://toggle_task?id=$taskId")
                        )
                        setOnClickPendingIntent(checkIds[i], toggleIntent)

                        val openTaskIntent = HomeWidgetLaunchIntent.getActivity(
                            context,
                            MainActivity::class.java,
                            Uri.parse("cairn://widget/tasks?id=$taskId")
                        )
                        setOnClickPendingIntent(titleIds[i], openTaskIntent)
                    }

                    visibleRows++
                } else {
                    setViewVisibility(rowIds[i], View.GONE)
                }
            }

            if (totalCount == 0 || visibleRows == 0) {
                setViewVisibility(R.id.tasks_empty_text, View.VISIBLE)
            } else {
                setViewVisibility(R.id.tasks_empty_text, View.GONE)
            }

            // Launch the Cairn Tasks screen on tap
            val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("cairn://widget/tasks")
            )
            setOnClickPendingIntent(R.id.tasks_widget_bg, pendingIntent)
        }

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
}
