package dev.bob2142.ai_usage_monitor

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/** Shows the most urgent budget pool; data is written from the Dart side. */
class UsageLedgerWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val launch =
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
        val flags =
            PendingIntent.FLAG_UPDATE_CURRENT or
                if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_IMMUTABLE else 0
        val pending = PendingIntent.getActivity(context, 0, launch, flags)

        for (appWidgetId in appWidgetIds) {
            val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
            val minWidth =
                options.getInt(
                    AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH,
                    0,
                )
            val layout =
                if (minWidth >= 250) {
                    R.layout.usage_ledger_widget_medium
                } else {
                    R.layout.usage_ledger_widget
                }
            val views =
                RemoteViews(context.packageName, layout).apply {
                    setTextViewText(
                        R.id.wl_label,
                        widgetData.getString("wl_label", "NEXT WALL"),
                    )
                    setTextViewText(
                        R.id.wl_pct,
                        widgetData.getString("wl_pct", "--"),
                    )
                    setTextViewText(
                        R.id.wl_used,
                        widgetData.getString("wl_used", "Add an account to start tracking"),
                    )
                    setTextViewText(R.id.wl_reset, widgetData.getString("wl_reset", ""))
                    setTextViewText(
                        R.id.wl_updated,
                        widgetData.getString("wl_updated", ""),
                    )
                    if (minWidth >= 250) {
                        setTextViewText(
                            R.id.wl_pool_1,
                            widgetData.getString("wl_pool_1", ""),
                        )
                        setTextViewText(
                            R.id.wl_pool_2,
                            widgetData.getString("wl_pool_2", ""),
                        )
                        setTextViewText(
                            R.id.wl_pool_3,
                            widgetData.getString("wl_pool_3", ""),
                        )
                    }
                    setOnClickPendingIntent(R.id.widget_root, pending)
                }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
