package dev.beetlebyte.cairn

import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray

class CairnTasksWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return CairnTasksViewsFactory(applicationContext)
    }
}

class CairnTasksViewsFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {

    data class TaskItem(val id: String, val title: String, val priority: Int)

    private val tasks = mutableListOf<TaskItem>()

    override fun onCreate() {
        loadData()
    }

    override fun onDataSetChanged() {
        loadData()
    }

    override fun onDestroy() {
        tasks.clear()
    }

    override fun getCount(): Int = tasks.size

    override fun getViewAt(position: Int): RemoteViews? {
        if (position !in tasks.indices) return null
        val task = tasks[position]

        val views = RemoteViews(context.packageName, R.layout.cairn_widget_task_item).apply {
            setTextViewText(R.id.task_title, task.title)

            if (task.priority in 1..3) {
                setViewVisibility(R.id.task_priority, View.VISIBLE)
                setTextViewText(R.id.task_priority, "P${task.priority}")
                val priorityColor = if (task.priority == 1) {
                    R.color.widget_accent
                } else {
                    R.color.widget_text_muted
                }
                setTextColor(R.id.task_priority, context.getColor(priorityColor))
            } else {
                setViewVisibility(R.id.task_priority, View.GONE)
            }

            // Fill-in intent for 1-tap toggle check-off
            val toggleFillIn = Intent().apply {
                putExtra(CairnTasksWidgetProvider.EXTRA_ACTION_TYPE, CairnTasksWidgetProvider.ACTION_TYPE_TOGGLE)
                putExtra(CairnTasksWidgetProvider.EXTRA_TASK_ID, task.id)
            }
            setOnClickFillInIntent(R.id.task_check, toggleFillIn)

            // Fill-in intent for opening the task in app
            val openFillIn = Intent().apply {
                putExtra(CairnTasksWidgetProvider.EXTRA_ACTION_TYPE, CairnTasksWidgetProvider.ACTION_TYPE_OPEN)
                putExtra(CairnTasksWidgetProvider.EXTRA_TASK_ID, task.id)
            }
            setOnClickFillInIntent(R.id.task_title, openFillIn)
            setOnClickFillInIntent(R.id.task_item_root, openFillIn)
        }
        return views
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = false

    private fun loadData() {
        tasks.clear()
        val widgetData = HomeWidgetPlugin.getData(context)
        val tasksJson = widgetData.getString("tasks_json", null)
        if (!tasksJson.isNullOrEmpty()) {
            try {
                val array = JSONArray(tasksJson)
                for (i in 0 until array.length()) {
                    val obj = array.getJSONObject(i)
                    tasks.add(
                        TaskItem(
                            id = obj.getString("id"),
                            title = obj.getString("title"),
                            priority = obj.optInt("priority", 4)
                        )
                    )
                }
                return
            } catch (_: Exception) {}
        }

        // Fallback to indexed keys
        val totalCount = widgetData.getInt("tasks_total_count", 0)
        val maxRows = maxOf(totalCount, 50)
        for (i in 1..maxRows) {
            val id = widgetData.getString("task_${i}_id", null)
            val title = widgetData.getString("task_${i}_title", null)
            val priority = widgetData.getInt("task_${i}_priority", 4)
            if (id != null && title != null) {
                tasks.add(TaskItem(id, title, priority))
            }
        }
    }
}
