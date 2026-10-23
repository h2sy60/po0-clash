package com.follow.clash

import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.WindowManager
import com.follow.clash.plugins.AppPlugin
import com.follow.clash.plugins.Po0ScreenPlugin
import com.follow.clash.plugins.ServicePlugin
import com.follow.clash.plugins.TilePlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    var isWhitelistBootstrap = false
        private set
    private val bootstrapHandler = Handler(Looper.getMainLooper())
    private var bootstrapEnginePending = false
    val needsWhitelistBootstrap: Boolean
        get() = bootstrapEnginePending
    private val parkBootstrap = Runnable { finishWhitelistBootstrap(true, ready = false) }

    override fun onCreate(savedInstanceState: Bundle?) {
        isWhitelistBootstrap = intent.getBooleanExtra(WHITELIST_BOOTSTRAP, false)
        bootstrapEnginePending = isWhitelistBootstrap
        intent.removeExtra(WHITELIST_BOOTSTRAP)
        super.onCreate(savedInstanceState)
        if (isWhitelistBootstrap) {
            window.attributes = window.attributes.apply { alpha = 0f }
            window.addFlags(WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE)
            bootstrapHandler.postDelayed(parkBootstrap, 30_000)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (!intent.getBooleanExtra(WHITELIST_BOOTSTRAP, false)) {
            finishWhitelistBootstrap(false, ready = false)
        }
    }

    fun finishWhitelistBootstrap(background: Boolean, ready: Boolean = true): Boolean {
        if (ready && bootstrapEnginePending) {
            flutterEngine?.let(ServiceState::attachFlutterEngine)
            bootstrapEnginePending = false
        }
        if (!isWhitelistBootstrap) return false
        isWhitelistBootstrap = false
        bootstrapHandler.removeCallbacks(parkBootstrap)
        val moved = background && moveTaskToBack(true)
        window.clearFlags(WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE)
        window.attributes = window.attributes.apply { alpha = 1f }
        return moved
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(AppPlugin())
        flutterEngine.plugins.add(ServicePlugin())
        flutterEngine.plugins.add(TilePlugin())
        flutterEngine.plugins.add(Po0ScreenPlugin())
        // Native quick actions must remain available until Dart can receive tile commands.
        if (!bootstrapEnginePending) ServiceState.attachFlutterEngine(flutterEngine)
    }

    override fun onDestroy() {
        bootstrapHandler.removeCallbacks(parkBootstrap)
        flutterEngine?.let(ServiceState::detachFlutterEngine)
        super.onDestroy()
    }

    companion object {
        const val WHITELIST_BOOTSTRAP = "po0.whitelistBootstrap"
    }
}
