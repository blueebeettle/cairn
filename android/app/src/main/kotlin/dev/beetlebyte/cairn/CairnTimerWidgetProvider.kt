package dev.beetlebyte.cairn

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin

class CairnTimerWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            val widgetData = HomeWidgetPlugin.getData(context)
            val views = RemoteViews(context.packageName, R.layout.cairn_timer_widget).apply {
                val status = widgetData.getString("timer_status", "idle") ?: "idle"
                val timeText = widgetData.getString("timer_time_text", "25:00") ?: "25:00"

                // Let the widget run its own clock while a session is live.
                // Chronometer counts in elapsedRealtime, so re-anchor the
                // absolute instant Dart handed us against the current boot clock.
                val countsDown = widgetData.getBoolean("timer_counts_down", true)
                // The key is absent while idle/paused, and the plugin may have
                // stored it as either width of integer, so never let a bad read
                // take the whole widget down.
                val anchorUtcMs = runCatching {
                    widgetData.getLong("timer_anchor_utc_ms", 0L)
                }.getOrDefault(0L)
                val ticking = widgetData.getBoolean("timer_ticking", false) &&
                    anchorUtcMs > 0L &&
                    // setChronometerCountDown landed in N; below that a
                    // counting-down Chronometer would run the wrong way.
                    (!countsDown || Build.VERSION.SDK_INT >= Build.VERSION_CODES.N)

                if (ticking) {
                    val base = SystemClock.elapsedRealtime() +
                        (anchorUtcMs - System.currentTimeMillis())
                    setChronometer(R.id.timer_chronometer, base, null, true)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        setChronometerCountDown(R.id.timer_chronometer, countsDown)
                    }
                    setViewVisibility(R.id.timer_chronometer, View.VISIBLE)
                    setViewVisibility(R.id.timer_time_text, View.GONE)
                } else {
                    setChronometer(R.id.timer_chronometer, SystemClock.elapsedRealtime(), null, false)
                    setViewVisibility(R.id.timer_chronometer, View.GONE)
                    setViewVisibility(R.id.timer_time_text, View.VISIBLE)
                    setTextViewText(R.id.timer_time_text, timeText)
                }

                val label = when (status) {
                    "running" -> "FOCUSING"
                    "paused" -> "PAUSED"
                    "break" -> "BREAK"
                    else -> "FOCUS"
                }
                setTextViewText(R.id.timer_status_label, label)

                // Buttons swap by visibility so one layout covers every state.
                // A running break has none: skipping it is an in-app flow.
                setViewVisibility(
                    R.id.timer_start_button,
                    if (status == "idle") View.VISIBLE else View.GONE
                )
                setViewVisibility(
                    R.id.timer_pause_button,
                    if (status == "running") View.VISIBLE else View.GONE
                )
                setViewVisibility(
                    R.id.timer_resume_button,
                    if (status == "paused") View.VISIBLE else View.GONE
                )
                setViewVisibility(
                    R.id.timer_stop_button,
                    if (status == "running" || status == "paused") View.VISIBLE else View.GONE
                )
                setViewVisibility(
                    R.id.timer_button_row,
                    if (status == "break") View.GONE else View.VISIBLE
                )

                // Silent background actions — these must not open the app.
                setOnClickPendingIntent(R.id.timer_start_button, timerAction(context, "start"))
                setOnClickPendingIntent(R.id.timer_pause_button, timerAction(context, "pause"))
                setOnClickPendingIntent(R.id.timer_resume_button, timerAction(context, "resume"))
                setOnClickPendingIntent(R.id.timer_stop_button, timerAction(context, "stop"))

                // Tapping the time or the background opens the Timer tab.
                val openTimer = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("cairn://widget/timer")
                )
                setOnClickPendingIntent(R.id.timer_time_text, openTimer)
                setOnClickPendingIntent(R.id.timer_chronometer, openTimer)
                setOnClickPendingIntent(R.id.timer_widget_bg, openTimer)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    private fun timerAction(context: Context, action: String) =
        HomeWidgetBackgroundIntent.getBroadcast(
            context,
            Uri.parse("cairn://timer_action?action=$action")
        )
}
