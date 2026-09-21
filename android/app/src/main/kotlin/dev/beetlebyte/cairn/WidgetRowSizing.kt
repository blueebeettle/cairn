package dev.beetlebyte.cairn

import android.appwidget.AppWidgetManager
import android.os.Bundle

/**
 * Works out how many list rows actually fit in the height the launcher gave a
 * widget, so a taller placement shows more rows instead of empty background.
 *
 * RemoteViews do not scale to fit, they clip, so this is measured rather than
 * guessed: take the height the launcher reports, subtract the widget's fixed
 * chrome (padding, header, progress bar), and divide by the row height. Row
 * height is driven by the 44dp check target plus its 4dp gap, so the numbers
 * here must move together with the layout XML.
 */
object WidgetRowSizing {

    /** The 4dp gap below each row; the last row does not need its own. */
    const val ROW_GAP_DP = 4

    /** One row: a 44dp tap target plus the gap below it. */
    const val ROW_HEIGHT_DP = 44 + ROW_GAP_DP

    /**
     * Habits: 14dp padding x2 + a 14sp title over an 11sp date (~34dp) +
     * the 6dp progress bar with its 8dp margins. Measured against a launcher
     * reporting 295dp, which fits four rows.
     */
    const val HABITS_CHROME_DP = 84

    /** Tasks: 14dp padding x2 + one 14sp header line and its 8dp margin. */
    const val TASKS_CHROME_DP = 56

    /**
     * Rows that fit in [appWidgetId]'s current height, clamped to
     * 1..[layoutRowCount].
     *
     * Falls back to the minimum height when the launcher has not reported a
     * maximum yet (it only populates OPTION_APPWIDGET_MAX_HEIGHT once the
     * widget has been laid out), and to [layoutRowCount] if it reports neither.
     */
    fun rowsThatFit(
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        chromeDp: Int,
        layoutRowCount: Int,
        options: Bundle? = null
    ): Int {
        val opts = options ?: appWidgetManager.getAppWidgetOptions(appWidgetId)
        val maxHeight = opts?.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0) ?: 0
        val minHeight = opts?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0) ?: 0
        val heightDp = if (maxHeight > 0) maxHeight else minHeight
        if (heightDp <= 0) return layoutRowCount

        // Add the gap back: the bottom row's trailing margin is not needed,
        // and without this a widget lands one row short of what really fits.
        val available = heightDp - chromeDp + ROW_GAP_DP
        val fits = available / ROW_HEIGHT_DP
        return fits.coerceIn(1, layoutRowCount)
    }
}
