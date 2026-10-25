package com.follow.clash.plugins

import com.follow.clash.common.GlobalState
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume

internal class CoreEventRelay(
    scope: CoroutineScope,
    private val channel: MethodChannel,
) {
    private val pending = Channel<String>(4)
    private val pump = scope.launch(Dispatchers.Main) {
        for (value in pending) {
            suspendCancellableCoroutine<Unit> { continuation ->
                val complete = {
                    if (continuation.isActive) continuation.resume(Unit)
                }
                try {
                    channel.invokeMethod("event", value, object : MethodChannel.Result {
                        override fun success(result: Any?) = complete()

                        override fun error(code: String, message: String?, details: Any?) {
                            GlobalState.log("Core event delivery failed: $code")
                            complete()
                        }

                        override fun notImplemented() = complete()
                    })
                } catch (error: Exception) {
                    GlobalState.log("Unable to deliver Core event: $error")
                    complete()
                }
            }
        }
    }.also { job ->
        job.invokeOnCompletion { pending.cancel() }
    }

    // Only the Go event batcher waits here; Core event producers keep their bounded queues.
    fun send(value: String?) {
        if (value == null) return
        val result = pending.trySend(value)
        if (result.isSuccess || result.isClosed) return
        try {
            runBlocking { pending.send(value) }
        } catch (_: CancellationException) {
        }
    }

    fun close() {
        pending.cancel()
        pump.cancel()
    }
}
