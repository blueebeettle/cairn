package dev.beetlebyte.cairn

import android.content.Context
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.util.TypedValue

/**
 * Draws a habit's check-off ring.
 *
 * A yes/no habit gets a plain circle: hollow until it is done, then filled with
 * a tick. A habit with a daily target of more than one — "8 glasses", "3 doses"
 * — gets the same circle split into that many arcs, with one arc filled per
 * check-off, so a glance shows how much of today is left.
 *
 * RemoteViews cannot express this in XML (the segment count is per-habit and
 * only known at render time), so it is rasterised here and shipped over with
 * setImageViewBitmap.
 */
object HabitRingRenderer {

    /** Drawn size of the ring. The tap target around it stays 44dp. */
    private const val SIZE_DP = 40f
    private const val STROKE_DP = 3.5f

    /** Degrees of blank left between arcs so the segments read as separate. */
    private const val GAP_DEGREES = 7f

    private val cache = HashMap<String, Bitmap>()

    fun render(context: Context, count: Int, target: Int, isDone: Boolean): Bitmap {
        val segments = if (target > 1) target else 1
        val filled = count.coerceIn(0, segments)
        val isNight = (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
        val key = "$segments:$filled:$isDone:$isNight"
        cache[key]?.let { return it }

        val size = dp(context, SIZE_DP).toInt().coerceAtLeast(1)
        val stroke = dp(context, STROKE_DP)
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        val inset = stroke / 2f + dp(context, 1f)
        val bounds = RectF(inset, inset, size - inset, size - inset)

        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = stroke
            strokeCap = Paint.Cap.ROUND
        }

        val trackColor = context.getColor(R.color.widget_text_muted)
        val doneColor = context.getColor(R.color.widget_check_done)
        val partialColor = context.getColor(R.color.widget_accent)
        val complete = isDone || filled >= segments

        if (segments == 1) {
            paint.color = if (complete) doneColor else trackColor
            canvas.drawOval(bounds, paint)
        } else {
            // -90 starts at twelve o'clock and fills clockwise, the direction a
            // progress ring is read.
            val sweep = 360f / segments - GAP_DEGREES
            for (i in 0 until segments) {
                val start = -90f + i * (360f / segments) + GAP_DEGREES / 2f
                paint.color = when {
                    i < filled && complete -> doneColor
                    i < filled -> partialColor
                    else -> trackColor
                }
                canvas.drawArc(bounds, start, sweep, false, paint)
            }
        }

        if (complete) {
            paint.style = Paint.Style.STROKE
            paint.color = doneColor
            paint.strokeWidth = dp(context, 3f)
            val c = size / 2f
            val r = size / 2f
            val tick = Path().apply {
                moveTo(c - r * 0.30f, c + r * 0.02f)
                lineTo(c - r * 0.08f, c + r * 0.26f)
                lineTo(c + r * 0.32f, c - r * 0.24f)
            }
            canvas.drawPath(tick, paint)
        } else if (segments > 1) {
            // Bare "2/5" in the middle: the ring says how far along, the
            // number says exactly where, without needing a separate label.
            val text = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = trackColor
                textAlign = Paint.Align.CENTER
                textSize = size * 0.34f
                isFakeBoldText = true
            }
            val mid = size / 2f - (text.descent() + text.ascent()) / 2f
            canvas.drawText("$filled", size / 2f, mid, text)
        }

        cache[key] = bitmap
        return bitmap
    }

    private fun dp(context: Context, value: Float): Float =
        TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            value,
            context.resources.displayMetrics
        )
}
