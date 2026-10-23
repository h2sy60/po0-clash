package com.follow.clash

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import androidx.core.content.pm.PackageInfoCompat
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat
import com.follow.clash.common.GlobalState
import com.follow.clash.common.QuickAction
import com.follow.clash.common.quickIntent

internal object LauncherBranding {
    private const val REVISION = 1
    private const val TOGGLE_ID = "toggle"

    fun refresh(context: Context) {
        try {
            val preferences = context.getSharedPreferences("po0.launcher_branding", Context.MODE_PRIVATE)
            val version = PackageInfoCompat.getLongVersionCode(
                context.packageManager.getPackageInfo(context.packageName, 0),
            )
            if (preferences.getLong("version", -1) == version &&
                preferences.getInt("revision", -1) == REVISION
            ) return

            refreshLauncher(context)
            val previous = ShortcutManagerCompat.getShortcuts(
                context,
                ShortcutManagerCompat.FLAG_MATCH_DYNAMIC or ShortcutManagerCompat.FLAG_MATCH_PINNED,
            ).firstOrNull { it.id == TOGGLE_ID }
            if (previous != null && !ShortcutManagerCompat.updateShortcuts(
                    context,
                    listOf(toggle(context, previous.shortLabel)),
                )
            ) return

            preferences.edit().putLong("version", version).putInt("revision", REVISION).apply()
        } catch (error: Exception) {
            GlobalState.log("Unable to refresh launcher branding: ${error.javaClass.simpleName}")
        }
    }

    fun publishToggle(context: Context, label: CharSequence) {
        try {
            val shortcuts = listOf(toggle(context, label))
            ShortcutManagerCompat.setDynamicShortcuts(context, shortcuts)
            ShortcutManagerCompat.updateShortcuts(context, shortcuts)
        } catch (error: Exception) {
            GlobalState.log("Unable to refresh shortcuts: ${error.javaClass.simpleName}")
        }
    }

    private fun toggle(context: Context, label: CharSequence): ShortcutInfoCompat =
        ShortcutInfoCompat.Builder(context, TOGGLE_ID)
            .setActivity(ComponentName(context, MainActivity::class.java))
            .setShortLabel(label)
            .setIcon(IconCompat.createWithResource(context, R.mipmap.po0_launcher_round))
            .setIntent(QuickAction.TOGGLE.quickIntent)
            .build()

    private fun refreshLauncher(context: Context) {
        val manager = context.packageManager
        val component = ComponentName(context, MainActivity::class.java)
        val next = when (manager.getComponentEnabledSetting(component)) {
            PackageManager.COMPONENT_ENABLED_STATE_DEFAULT -> PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> PackageManager.COMPONENT_ENABLED_STATE_DEFAULT
            else -> return
        }
        // Both states keep the launcher enabled, preserving existing home-screen positions.
        manager.setComponentEnabledSetting(component, next, PackageManager.DONT_KILL_APP)
    }
}
