package dev.bob2142.ai_usage_monitor

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
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
        val views =
            RemoteViews(context.packageName, R.layout.usage_ledger_widget).apply {
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
                    widgetData.getString("wl_used", "Sync to track your pools"),
                )
                setTextViewText(R.id.wl_reset, widgetData.getString("wl_reset", ""))
                setTextViewText(
                    R.id.wl_updated,
                    widgetData.getString("wl_updated", ""),
                )
            }
        appWidgetManager.updateAppWidget(appWidgetIds, views)
    }
}
