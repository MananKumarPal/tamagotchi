package com.manankumar.eggling

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.res.ColorStateList
import android.graphics.BitmapFactory
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject

/**
 * Renders the saved forecast. Nothing is simulated here: the widget picks the
 * forecast entry for "now", adds taps still queued, and the app replays those
 * taps at their own timestamps on next open.
 */
class EgglingWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { render(context, manager, it) }
        scheduleNext(context)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context, manager: AppWidgetManager, id: Int, options: Bundle,
    ) = render(context, manager, id)

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_MEAL -> { WidgetStore.append(context, "meal"); refreshAll(context) }
            ACTION_SNACK -> { WidgetStore.append(context, "snack"); refreshAll(context) }
            ACTION_TICK, Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED -> refreshAll(context)
            else -> super.onReceive(context, intent)
        }
    }

    companion object {
        private const val ACTION_MEAL = "com.manankumar.eggling.MEAL"
        private const val ACTION_SNACK = "com.manankumar.eggling.SNACK"
        private const val ACTION_TICK = "com.manankumar.eggling.TICK"
        private const val STALE_MS = 24L * 60 * 60 * 1000

        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, EgglingWidgetProvider::class.java))
            ids.forEach { render(context, manager, it) }
            if (ids.isNotEmpty()) scheduleNext(context)
        }

        private fun selfIntent(context: Context, action: String, code: Int) = PendingIntent.getBroadcast(
            context, code,
            Intent(context, EgglingWidgetProvider::class.java).setAction(action),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        private fun openIntent(context: Context, route: String, code: Int) = PendingIntent.getActivity(
            context, code,
            Intent(Intent.ACTION_VIEW, Uri.parse("eggling://open/$route"), context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        private fun currentEntry(snapshot: JSONObject?, now: Long): JSONObject? {
            val entries = snapshot?.optJSONArray("entries") ?: return null
            var found: JSONObject? = null
            for (i in 0 until entries.length()) {
                val entry = entries.getJSONObject(i)
                if (found == null || entry.getLong("at") <= now) found = entry
            }
            return found
        }

        /** An inexact wake for the next forecast change. Respects Doze. */
        private fun scheduleNext(context: Context) {
            val entries = WidgetStore.snapshot(context)?.optJSONArray("entries") ?: return
            val now = System.currentTimeMillis()
            for (i in 0 until entries.length()) {
                val at = entries.getJSONObject(i).getLong("at")
                if (at > now) {
                    val alarms = context.getSystemService(AlarmManager::class.java)
                    alarms.set(AlarmManager.RTC, at, selfIntent(context, ACTION_TICK, 9))
                    return
                }
            }
        }

        private fun hearts(n: Int) = "●".repeat(n) + "○".repeat(4 - n)

        /** Runtime tints need API 31. Older phones keep the default colours. */
        private fun tint(views: RemoteViews, id: Int, hex: String?) {
            if (hex == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
            views.setColorStateList(id, "setBackgroundTintList", ColorStateList.valueOf(Color.parseColor(hex)))
        }

        private fun render(context: Context, manager: AppWidgetManager, id: Int) {
            val wide = manager.getAppWidgetOptions(id)
                .getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0) >= 220
            val views = RemoteViews(context.packageName, if (wide) R.layout.widget_wide else R.layout.widget_small)
            val now = System.currentTimeMillis()
            val snapshot = WidgetStore.snapshot(context)
            val pet = snapshot?.optJSONObject("pet")
            val entry = currentEntry(snapshot, now)
            views.setOnClickPendingIntent(R.id.widget_root, openIntent(context, "room", 1))

            if (pet == null || entry == null) {
                views.setTextViewText(R.id.widget_name, "eggling")
                views.setTextViewText(R.id.widget_hint, "open the app to hatch an egg")
                views.setViewVisibility(R.id.widget_sprite, View.GONE)
                if (wide) views.setViewVisibility(R.id.widget_keys, View.GONE)
                manager.updateAppWidget(id, views)
                return
            }

            val queue = WidgetStore.actionLines(context)
            val meals = queue.count { it.contains("\"meal\"") }
            val snacks = queue.count { it.contains("\"snack\"") }
            val entries = snapshot.getJSONArray("entries")
            val last = entries.getJSONObject(entries.length() - 1).getLong("at")
            val pose = entry.getString("pose")
            val hint = when {
                pose == "departed" -> "open to hatch a new egg"
                now - last > STALE_MS -> "open to check in"
                meals + snacks > 0 -> "saved. applies when you open eggling"
                else -> entry.getString("hint")
            }
            val name = pet.getString("name")
            val hunger = minOf(4, entry.getInt("hunger") + meals)
            val happy = minOf(4, entry.getInt("happy") + snacks)

            views.setTextViewText(R.id.widget_name, name)
            views.setTextViewText(R.id.widget_hint, hint)
            views.setViewVisibility(R.id.widget_sprite, View.VISIBLE)
            tint(views, R.id.widget_root, pet.optString("soft").ifEmpty { null })
            val file = WidgetStore.sprite(context, pose)
            if (file.exists()) {
                views.setImageViewBitmap(R.id.widget_sprite, BitmapFactory.decodeFile(file.path))
            }
            views.setContentDescription(R.id.widget_root, "$name. $hint.")
            if (wide) {
                val feedable = pose != "egg" && pose != "departed"
                views.setViewVisibility(R.id.widget_keys, if (feedable) View.VISIBLE else View.GONE)
                views.setTextViewText(R.id.widget_food, "food ${hearts(hunger)}")
                views.setTextViewText(R.id.widget_joy, "joy  ${hearts(happy)}")
                views.setContentDescription(R.id.widget_food, "Hunger $hunger of 4")
                views.setContentDescription(R.id.widget_joy, "Happiness $happy of 4")
                val canMeal = entry.getBoolean("canFeed") && hunger < 4
                val canSnack = entry.getBoolean("canPlay")
                val accent = pet.optString("accent").ifEmpty { null }
                if (canMeal) tint(views, R.id.widget_meal, accent)
                if (canSnack) tint(views, R.id.widget_snack, accent)
                views.setOnClickPendingIntent(R.id.widget_meal,
                    if (canMeal) selfIntent(context, ACTION_MEAL, 2) else openIntent(context, "feed", 3))
                views.setOnClickPendingIntent(R.id.widget_snack,
                    if (canSnack) selfIntent(context, ACTION_SNACK, 4) else openIntent(context, "feed", 5))
                views.setOnClickPendingIntent(R.id.widget_play, openIntent(context, "game", 6))
            }
            manager.updateAppWidget(id, views)
        }
    }
}
