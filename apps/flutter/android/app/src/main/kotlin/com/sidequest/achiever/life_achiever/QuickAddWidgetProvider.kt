package com.sidequest.achiever.life_achiever

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home-screen quick-add widget: each button launches the app with a
 * lifeos:// URI that the Flutter side turns into the matching add sheet.
 */
class QuickAddWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_quick_add).apply {
                setOnClickPendingIntent(
                    R.id.widget_add_expense,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("lifeos://add-expense")
                    )
                )
                setOnClickPendingIntent(
                    R.id.widget_add_meal,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("lifeos://add-meal")
                    )
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
