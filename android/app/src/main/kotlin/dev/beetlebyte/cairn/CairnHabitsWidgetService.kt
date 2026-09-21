package dev.beetlebyte.cairn

import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray

class CairnHabitsWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return CairnHabitsViewsFactory(applicationContext)
    }
}

class CairnHabitsViewsFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {

    data class HabitItem(
        val id: String,
        val title: String,
        val isDone: Boolean,
        val streak: String,
        val count: Int,
        val target: Int
    )

    private val habits = mutableListOf<HabitItem>()

    override fun onCreate() {
        loadData()
    }

    override fun onDataSetChanged() {
        loadData()
    }

    override fun onDestroy() {
        habits.clear()
    }

    override fun getCount(): Int = habits.size

    override fun getViewAt(position: Int): RemoteViews? {
        if (position !in habits.indices) return null
        val habit = habits[position]

        val views = RemoteViews(context.packageName, R.layout.cairn_widget_habit_item).apply {
            setTextViewText(R.id.habit_title, habit.title)
            setTextViewText(R.id.habit_streak, habit.streak)

            setImageViewBitmap(
                R.id.habit_check,
                HabitRingRenderer.render(context, habit.count, habit.target, habit.isDone)
            )

            // Fill-in intent for 1-tap toggle / check-off
            val toggleFillIn = Intent().apply {
                putExtra(CairnHabitsWidgetProvider.EXTRA_ACTION_TYPE, CairnHabitsWidgetProvider.ACTION_TYPE_TOGGLE)
                putExtra(CairnHabitsWidgetProvider.EXTRA_HABIT_ID, habit.id)
            }
            setOnClickFillInIntent(R.id.habit_check, toggleFillIn)

            // Fill-in intent for opening the habit detail in app
            val openFillIn = Intent().apply {
                putExtra(CairnHabitsWidgetProvider.EXTRA_ACTION_TYPE, CairnHabitsWidgetProvider.ACTION_TYPE_OPEN)
                putExtra(CairnHabitsWidgetProvider.EXTRA_HABIT_ID, habit.id)
            }
            setOnClickFillInIntent(R.id.habit_title, openFillIn)
            setOnClickFillInIntent(R.id.habit_item_root, openFillIn)
        }
        return views
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = false

    private fun loadData() {
        habits.clear()
        val widgetData = HomeWidgetPlugin.getData(context)
        val habitsJson = widgetData.getString("habits_json", null)
        if (!habitsJson.isNullOrEmpty()) {
            try {
                val array = JSONArray(habitsJson)
                for (i in 0 until array.length()) {
                    val obj = array.getJSONObject(i)
                    habits.add(
                        HabitItem(
                            id = obj.getString("id"),
                            title = obj.getString("title"),
                            isDone = obj.optBoolean("done", false),
                            streak = obj.optString("streak", ""),
                            count = obj.optInt("count", 0),
                            target = obj.optInt("target", 1)
                        )
                    )
                }
                return
            } catch (_: Exception) {}
        }

        // Fallback to indexed keys
        val totalCount = widgetData.getInt("habits_total_count", 0)
        val maxRows = maxOf(totalCount, 50)
        for (i in 1..maxRows) {
            val id = widgetData.getString("habit_${i}_id", null)
            val title = widgetData.getString("habit_${i}_title", null)
            if (id != null && title != null) {
                val isDone = widgetData.getBoolean("habit_${i}_done", false)
                val streak = widgetData.getString("habit_${i}_streak", "") ?: ""
                val count = widgetData.getInt("habit_${i}_count", 0)
                val target = widgetData.getInt("habit_${i}_target", 1)
                habits.add(HabitItem(id, title, isDone, streak, count, target))
            }
        }
    }
}
