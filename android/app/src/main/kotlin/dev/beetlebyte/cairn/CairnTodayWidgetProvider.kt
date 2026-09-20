package dev.beetlebyte.cairn

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin

class CairnTodayWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            val widgetData = HomeWidgetPlugin.getData(context)
            val views = RemoteViews(context.packageName, R.layout.cairn_today_widget).apply {
                val focusMins = widgetData.getString("today_focus_mins", "0m") ?: "0m"
                val habitsDone = widgetData.getString("today_habits_summary", "0 / 0") ?: "0 / 0"
                val tasksDue = widgetData.getString("today_tasks_due", "0") ?: "0"

                setTextViewText(R.id.today_focus_value, focusMins)
                setTextViewText(R.id.today_habits_value, habitsDone)
                setTextViewText(R.id.today_tasks_value, tasksDue)

                // Launch intents for sections
                val timerIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("cairn://widget/timer")
                )
                val habitsIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("cairn://widget/habits")
                )
                val todayIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("cairn://widget/today")
                )

                setOnClickPendingIntent(R.id.today_focus_section, timerIntent)
                setOnClickPendingIntent(R.id.today_habits_section, habitsIntent)
                setOnClickPendingIntent(R.id.today_tasks_section, todayIntent)
                setOnClickPendingIntent(R.id.today_widget_root, todayIntent)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
