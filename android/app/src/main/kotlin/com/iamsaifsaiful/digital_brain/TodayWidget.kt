package com.iamsaifsaiful.digital_brain

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/**
 * Home-screen widget: today's date, the Bangla date, the next few
 * reminders and to-dos, and a mic that opens the assistant listening.
 * The app writes the lines (see MainActivity "widget"); this only shows them.
 */
class TodayWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) manager.updateAppWidget(id, views(context))
    }

    companion object {
        const val PREFS = "my_assistant_widget"
        const val VOICE = "com.iamsaifsaiful.digital_brain.VOICE"

        fun views(context: Context): RemoteViews {
            val p = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val v = RemoteViews(context.packageName, R.layout.widget_today)
            v.setTextViewText(R.id.widget_date, p.getString("date", "My Assistant"))
            v.setTextViewText(R.id.widget_bangla, p.getString("bangla", ""))
            v.setTextViewText(R.id.widget_lines, p.getString("lines", "মাইক চাপুন, তারপর বলুন"))
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            val open = Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            v.setOnClickPendingIntent(R.id.widget_body, PendingIntent.getActivity(context, 1, open, flags))
            val voice = Intent(context, MainActivity::class.java).setAction(VOICE)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            v.setOnClickPendingIntent(R.id.widget_mic, PendingIntent.getActivity(context, 2, voice, flags))
            return v
        }

        fun refresh(context: Context) {
            val m = AppWidgetManager.getInstance(context)
            val ids = m.getAppWidgetIds(ComponentName(context, TodayWidget::class.java))
            for (id in ids) m.updateAppWidget(id, views(context))
        }
    }
}
