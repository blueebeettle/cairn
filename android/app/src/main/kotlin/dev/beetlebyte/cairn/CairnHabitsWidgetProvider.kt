package dev.beetlebyte.cairn

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin

class CairnHabitsWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            val widgetData = HomeWidgetPlugin.getData(context)
            val views = RemoteViews(context.packageName, R.layout.cairn_habits_widget).apply {
                val date = widgetData.getString("habits_date", "Today") ?: "Today"
                val summary = widgetData.getString("habits_summary", "0 / 0 Done") ?: "0 / 0 Done"
                val progress = widgetData.getInt("habits_percent", 0)
                val totalCount = widgetData.getInt("habits_total_count", 0)

                setTextViewText(R.id.widget_date, date)
                setTextViewText(R.id.widget_progress_text, summary)
                setProgressBar(R.id.widget_progress_bar, 100, progress, false)

                val rowIds = arrayOf(R.id.habit_row_1, R.id.habit_row_2, R.id.habit_row_3, R.id.habit_row_4)
                val checkIds = arrayOf(R.id.habit_1_check, R.id.habit_2_check, R.id.habit_3_check, R.id.habit_4_check)
                val titleIds = arrayOf(R.id.habit_1_title, R.id.habit_2_title, R.id.habit_3_title, R.id.habit_4_title)
                val streakIds = arrayOf(R.id.habit_1_streak, R.id.habit_2_streak, R.id.habit_3_streak, R.id.habit_4_streak)

                var visibleRows = 0
                for (i in 0 until 4) {
                    val habitTitle = widgetData.getString("habit_${i + 1}_title", null)
                    if (habitTitle != null) {
                        val isDone = widgetData.getBoolean("habit_${i + 1}_done", false)
                        val streak = widgetData.getString("habit_${i + 1}_streak", "") ?: ""

                        setViewVisibility(rowIds[i], View.VISIBLE)
                        setTextViewText(titleIds[i], habitTitle)
                        setTextViewText(streakIds[i], streak)

                        if (isDone) {
                            setTextViewText(checkIds[i], "✓")
                            setTextColor(checkIds[i], context.getColor(R.color.widget_check_done))
                        } else {
                            setTextViewText(checkIds[i], "○")
                            setTextColor(checkIds[i], context.getColor(R.color.widget_text_muted))
                        }
                        visibleRows++
                    } else {
                        setViewVisibility(rowIds[i], View.GONE)
                    }
                }

                if (totalCount > 0 && visibleRows == 0) {
                    setViewVisibility(R.id.widget_empty_text, View.VISIBLE)
                } else {
                    setViewVisibility(R.id.widget_empty_text, View.GONE)
                }

                // Launch Cairn Habits screen on tap
                val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("cairn://widget/habits")
                )
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
