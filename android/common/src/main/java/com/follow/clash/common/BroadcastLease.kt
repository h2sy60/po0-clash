package com.follow.clash.common

import java.util.concurrent.atomic.AtomicReference

/**
 * A `BroadcastReceiver.goAsync()` path holds the broadcast open until its
 * `PendingResult` is finished, and finishing twice throws. Normal completion and
 * the timeout watchdog both race to release it, so the winner is decided here
 * rather than by whichever callback happens to run first.
 *
 * Releasing the lease says only that Android may stop waiting for this receiver.
 * It does not cancel, reverse, or otherwise redefine the work the broadcast
 * started, which keeps running under its own owner.
 */
class BroadcastLease(release: () -> Unit) {
    private val pendingRelease = AtomicReference<(() -> Unit)?>(release)

    val isReleased: Boolean
        get() = pendingRelease.get() == null

    fun release(onRelease: () -> Unit = {}): Boolean {
        val release = pendingRelease.getAndSet(null) ?: return false
        try {
            onRelease()
        } finally {
            release.invoke()
        }
        return true
    }
}
