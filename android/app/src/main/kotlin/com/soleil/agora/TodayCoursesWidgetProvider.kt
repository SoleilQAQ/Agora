package com.soleil.agora

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray
import java.text.SimpleDateFormat
import java.util.Locale

/**
 * 今日课程小组件 Provider
 * 支持莫奈动态取色、响应式布局和列表滑动
 */
class TodayCoursesWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val PREFS_NAME = "HomeWidgetPreferences"
        private const val KEY_TODAY_COURSES = "today_courses"
        private const val KEY_CURRENT_WEEK = "current_week"
        private const val KEY_LAST_UPDATE = "last_update"
        const val ACTION_REFRESH = "com.soleil.agora.ACTION_REFRESH_COURSES"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle?
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        updateAppWidget(context, appWidgetManager, appWidgetId)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        
        if (intent.action == ACTION_REFRESH || 
            intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, TodayCoursesWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
            
            // 通知数据变更
            appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetIds, R.id.courses_list)
            
            for (appWidgetId in appWidgetIds) {
                updateAppWidget(context, appWidgetManager, appWidgetId)
            }
        }
    }

    private fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        try {
            val views = RemoteViews(context.packageName, R.layout.today_courses_widget)
            
            // 获取小组件尺寸，判断是否使用紧凑模式
            val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
            val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 200)
            val isCompact = minWidth < 200 // 小于200dp使用紧凑模式
            
            // 获取数据
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val coursesJson = prefs.getString(KEY_TODAY_COURSES, null)
            val currentWeek = prefs.getInt(KEY_CURRENT_WEEK, 1)
            val lastUpdate = prefs.getString(KEY_LAST_UPDATE, null)
            
            // 设置周次
            views.setTextViewText(R.id.widget_week, "第${currentWeek}周")
            
            // 设置更新时间
            val updateTimeText = formatUpdateTime(lastUpdate)
            views.setTextViewText(R.id.widget_update_time, updateTimeText)
            
            // 检查是否有数据
            val hasData = coursesJson != null && coursesJson != "[]"
            val courses = if (hasData) parseCourses(coursesJson) else emptyList()
            
            if (coursesJson == null) {
                // 从未加载过数据，显示加载提示
                views.setViewVisibility(R.id.courses_list, View.GONE)
                views.setViewVisibility(R.id.empty_view, View.GONE)
                views.setViewVisibility(R.id.loading_view, View.VISIBLE)
                views.setTextViewText(R.id.loading_text, "点击加载课程")
            } else if (courses.isEmpty()) {
                // 今天没有课程
                views.setViewVisibility(R.id.courses_list, View.GONE)
                views.setViewVisibility(R.id.loading_view, View.GONE)
                views.setViewVisibility(R.id.empty_view, View.VISIBLE)
            } else {
                // 有课程，显示列表
                views.setViewVisibility(R.id.empty_view, View.GONE)
                views.setViewVisibility(R.id.loading_view, View.GONE)
                views.setViewVisibility(R.id.courses_list, View.VISIBLE)
                
                // 设置 ListView 适配器，传递紧凑模式参数
                val serviceIntent = Intent(context, CoursesWidgetService::class.java).apply {
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                    putExtra(CoursesWidgetService.EXTRA_COMPACT_MODE, isCompact)
                    data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
                }
                views.setRemoteAdapter(R.id.courses_list, serviceIntent)
                views.setEmptyView(R.id.courses_list, R.id.empty_view)
            }
            
            // 设置点击事件 - 打开应用
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launchIntent != null) {
                val pendingIntent = android.app.PendingIntent.getActivity(
                    context,
                    appWidgetId,
                    launchIntent,
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)
                
                // 设置列表项点击模板
                views.setPendingIntentTemplate(R.id.courses_list, pendingIntent)
            }
            
            // 更新小组件
            appWidgetManager.updateAppWidget(appWidgetId, views)
            
        } catch (e: Exception) {
            // 发生错误时显示加载状态
            try {
                val errorViews = RemoteViews(context.packageName, R.layout.today_courses_widget)
                errorViews.setViewVisibility(R.id.courses_list, View.GONE)
                errorViews.setViewVisibility(R.id.empty_view, View.GONE)
                errorViews.setViewVisibility(R.id.loading_view, View.VISIBLE)
                errorViews.setTextViewText(R.id.loading_text, "点击重新加载")
                
                val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                if (launchIntent != null) {
                    val pendingIntent = android.app.PendingIntent.getActivity(
                        context,
                        appWidgetId,
                        launchIntent,
                        android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
                    )
                    errorViews.setOnClickPendingIntent(R.id.widget_container, pendingIntent)
                }
                
                appWidgetManager.updateAppWidget(appWidgetId, errorViews)
            } catch (innerE: Exception) {
                // 忽略内部错误
            }
        }
    }

    private fun formatUpdateTime(lastUpdate: String?): String {
        if (lastUpdate.isNullOrEmpty()) {
            return "点击刷新"
        }
        return try {
            val dateFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault())
            val date = dateFormat.parse(lastUpdate.substringBefore("."))
            val displayFormat = SimpleDateFormat("HH:mm 更新", Locale.getDefault())
            displayFormat.format(date!!)
        } catch (e: Exception) {
            "点击刷新"
        }
    }

    private fun parseCourses(coursesJson: String?): List<CourseItem> {
        if (coursesJson.isNullOrEmpty()) return emptyList()
        return try {
            val jsonArray = JSONArray(coursesJson)
            (0 until jsonArray.length()).map { i ->
                val obj = jsonArray.getJSONObject(i)
                CourseItem(
                    name = obj.optString("name", "未知课程"),
                    location = obj.optString("location", ""),
                    startSection = obj.optInt("startSection", 0),
                    endSection = obj.optInt("endSection", 0),
                    startTime = obj.optString("startTime", ""),
                    endTime = obj.optString("endTime", "")
                )
            }
        } catch (e: Exception) {
            emptyList()
        }
    }

    override fun onEnabled(context: Context) {
        // 小组件首次添加
    }

    override fun onDisabled(context: Context) {
        // 最后一个小组件被移除
    }
}

/**
 * 课程数据类
 */
data class CourseItem(
    val name: String,
    val location: String,
    val startSection: Int,
    val endSection: Int,
    val startTime: String,
    val endTime: String
)
