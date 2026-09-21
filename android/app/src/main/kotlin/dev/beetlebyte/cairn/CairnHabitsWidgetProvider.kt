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

class CairnHabitsWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            render(context, appWidgetManager, appWidgetId, null)
        }
    }

    /**
     * A resize alone does not trigger onUpdate, so without this a taller
     * widget just grows its background instead of showing more habits.
     */
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
        val views = RemoteViews(context.packageName, R.layout.cairn_habits_widget).apply {
            val date = widgetData.getString("habits_date", "Today") ?: "Today"
            val summary = widgetData.getString("habits_summary", "0 / 0 Done") ?: "0 / 0 Done"
            val progress = widgetData.getInt("habits_percent", 0)
            val totalCount = widgetData.getInt("habits_total_count", 0)

            setTextViewText(R.id.widget_date, date)
            setTextViewText(R.id.widget_progress_text, summary)
            setProgressBar(R.id.widget_progress_bar, 100, progress, false)

            val rowIds = arrayOf(
                R.id.habit_row_1, R.id.habit_row_2, R.id.habit_row_3, R.id.habit_row_4,
                R.id.habit_row_5, R.id.habit_row_6, R.id.habit_row_7, R.id.habit_row_8
            )
            val checkIds = arrayOf(
                R.id.habit_1_check, R.id.habit_2_check, R.id.habit_3_check, R.id.habit_4_check,
                R.id.habit_5_check, R.id.habit_6_check, R.id.habit_7_check, R.id.habit_8_check
            )
            val titleIds = arrayOf(
                R.id.habit_1_title, R.id.habit_2_title, R.id.habit_3_title, R.id.habit_4_title,
                R.id.habit_5_title, R.id.habit_6_title, R.id.habit_7_title, R.id.habit_8_title
            )
            val streakIds = arrayOf(
                R.id.habit_1_streak, R.id.habit_2_streak, R.id.habit_3_streak, R.id.habit_4_streak,
                R.id.habit_5_streak, R.id.habit_6_streak, R.id.habit_7_streak, R.id.habit_8_streak
            )

            val rowCap = WidgetRowSizing.rowsThatFit(
                appWidgetManager,
                appWidgetId,
                WidgetRowSizing.HABITS_CHROME_DP,
                rowIds.size,
                options
            )

            var visibleRows = 0
            for (i in rowIds.indices) {
                val habitTitle = widgetData.getString("habit_${i + 1}_title", null)
                val habitId = widgetData.getString("habit_${i + 1}_id", null)
                if (habitTitle != null && i < rowCap) {
                    val isDone = widgetData.getBoolean("habit_${i + 1}_done", false)
                    val streak = widgetData.getString("habit_${i + 1}_streak", "") ?: ""
                    val count = widgetData.getInt("habit_${i + 1}_count", 0)
                    val target = widgetData.getInt("habit_${i + 1}_target", 1)

                    setViewVisibility(rowIds[i], View.VISIBLE)
                    setTextViewText(titleIds[i], habitTitle)
                    setTextViewText(streakIds[i], streak)
                    setImageViewBitmap(
                        checkIds[i],
                        HabitRingRenderer.render(context, count, target, isDone)
                    )

                    if (habitId != null) {
                        val toggleIntent = HomeWidgetBackgroundIntent.getBroadcast(
                            context,
                            Uri.parse("cairn://toggle_habit?id=$habitId")
                        )
                        setOnClickPendingIntent(checkIds[i], toggleIntent)

                        val openHabitIntent = HomeWidgetLaunchIntent.getActivity(
                            context,
                            MainActivity::class.java,
                            Uri.parse("cairn://widget/habits?id=$habitId")
                        )
                        setOnClickPendingIntent(titleIds[i], openHabitIntent)
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
            setOnClickPendingIntent(R.id.widget_bg, pendingIntent)
        }

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
}
