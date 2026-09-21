package dev.beetlebyte.cairn

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin

class CairnHabitsWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_HABIT_CLICK = "dev.beetlebyte.cairn.ACTION_HABIT_CLICK"
        const val EXTRA_ACTION_TYPE = "dev.beetlebyte.cairn.EXTRA_ACTION_TYPE"
        const val EXTRA_HABIT_ID = "dev.beetlebyte.cairn.EXTRA_HABIT_ID"
        const val ACTION_TYPE_TOGGLE = "TOGGLE"
        const val ACTION_TYPE_OPEN = "OPEN"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            render(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        render(context, appWidgetManager, appWidgetId)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_HABIT_CLICK) {
            val actionType = intent.getStringExtra(EXTRA_ACTION_TYPE)
            val habitId = intent.getStringExtra(EXTRA_HABIT_ID) ?: return

            if (actionType == ACTION_TYPE_TOGGLE) {
                val toggleIntent = Intent(context, es.antonborri.home_widget.HomeWidgetBackgroundReceiver::class.java).apply {
                    action = "es.antonborri.home_widget.action.BACKGROUND"
                    data = Uri.parse("cairn://toggle_habit?id=$habitId")
                }
                context.sendBroadcast(toggleIntent)
            } else if (actionType == ACTION_TYPE_OPEN) {
                val openIntent = Intent(context, MainActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
                    data = Uri.parse("cairn://widget/habits?id=$habitId")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                context.startActivity(openIntent)
            }
        }
    }

    private fun render(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        val widgetData = HomeWidgetPlugin.getData(context)
        val views = RemoteViews(context.packageName, R.layout.cairn_habits_widget).apply {
            val date = widgetData.getString("habits_date", "Today") ?: "Today"
            val summary = widgetData.getString("habits_summary", "0 / 0 Done") ?: "0 / 0 Done"
            val progress = widgetData.getInt("habits_percent", 0)

            setTextViewText(R.id.widget_date, date)
            setTextViewText(R.id.widget_progress_text, summary)
            setProgressBar(R.id.widget_progress_bar, 100, progress, false)

            // Connect RemoteViewsService for scrollable ListView
            val serviceIntent = Intent(context, CairnHabitsWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
            }
            setRemoteAdapter(R.id.habits_list, serviceIntent)
            setEmptyView(R.id.habits_list, R.id.widget_empty_text)

            // Template PendingIntent for collection items
            val itemClickIntent = Intent(context, CairnHabitsWidgetProvider::class.java).apply {
                action = ACTION_HABIT_CLICK
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            }
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
            val itemClickPendingIntent = PendingIntent.getBroadcast(
                context,
                appWidgetId,
                itemClickIntent,
                flags
            )
            setPendingIntentTemplate(R.id.habits_list, itemClickPendingIntent)

            // Launch Cairn Habits screen on tap of background or title
            val launchIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("cairn://widget/habits")
            )
            setOnClickPendingIntent(R.id.widget_bg, launchIntent)
            setOnClickPendingIntent(R.id.widget_title, launchIntent)
        }

        appWidgetManager.updateAppWidget(appWidgetId, views)
        try {
            appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.habits_list)
        } catch (e: Exception) {
            // Widget may be removed or in the process of deletion
        }
    }
}
