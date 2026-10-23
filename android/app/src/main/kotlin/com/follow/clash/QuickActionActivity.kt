package com.follow.clash

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import androidx.core.content.pm.ShortcutManagerCompat
import com.follow.clash.common.GlobalState
import com.follow.clash.common.QuickAction
import com.follow.clash.common.action
import kotlinx.coroutines.launch
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class QuickActionActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val action = intent.action
        if (action == QuickAction.TOGGLE.action) {
            ShortcutManagerCompat.reportShortcutUsed(this, SHORTCUT_ID)
        }
        GlobalState.launch {
            try {
                when (action) {
                    QuickAction.START.action -> ServiceState.handleStartAction()
                    QuickAction.STOP.action -> ServiceState.handleStopAction()
                    QuickAction.TOGGLE.action -> ServiceState.handleToggleAction()
                }
                withContext(Dispatchers.Main) {
                    if (action != QuickAction.STOP.action && shouldBootstrapWhitelist(
                            enabled = application.whitelistEnabled,
                            hasFlutterEngine = ServiceState.hasFlutterEngine,
                            running = ServiceState.captureRequestToken().running &&
                                ServiceState.runState.value == RunState.STARTED &&
                                ServiceController.getRunTimeMillis() != 0L,
                        )
                    ) {
                        startActivity(Intent(this@QuickActionActivity, MainActivity::class.java).apply {
                            putExtra(MainActivity.WHITELIST_BOOTSTRAP, true)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_NO_ANIMATION)
                        })
                    }
                }
            } finally {
                withContext(Dispatchers.Main) { finish() }
            }
        }
    }

    private companion object {
        const val SHORTCUT_ID = "toggle"
    }
}
