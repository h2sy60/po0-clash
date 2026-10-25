package com.follow.clash.plugins

import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec
import java.nio.ByteBuffer
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import kotlinx.coroutines.test.StandardTestDispatcher
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

private class EventMessenger : BinaryMessenger {
    val values = mutableListOf<String>()
    val replies = ArrayDeque<BinaryMessenger.BinaryReply>()

    override fun send(channel: String, message: ByteBuffer?) = Unit

    override fun send(
        channel: String,
        message: ByteBuffer?,
        callback: BinaryMessenger.BinaryReply?,
    ) {
        message!!.flip()
        val call = StandardMethodCodec.INSTANCE.decodeMethodCall(message)
        assertEquals("event", call.method)
        values.add(call.arguments as String)
        replies.addLast(callback!!)
    }

    override fun setMessageHandler(
        channel: String,
        handler: BinaryMessenger.BinaryMessageHandler?,
    ) = Unit

    fun acknowledge() {
        val envelope = StandardMethodCodec.INSTANCE.encodeSuccessEnvelope(null)
        envelope.flip()
        replies.removeFirst().reply(envelope)
    }
}

@OptIn(ExperimentalCoroutinesApi::class)
class CoreEventRelayTest {
    @Test
    fun `waits for each Dart acknowledgement before sending the next batch`() = runTest {
        Dispatchers.setMain(StandardTestDispatcher(testScheduler))
        val messenger = EventMessenger()
        val relay = CoreEventRelay(backgroundScope, MethodChannel(messenger, "core"))
        try {
            relay.send("first")
            relay.send("second")
            runCurrent()
            assertEquals(listOf("first"), messenger.values)

            messenger.acknowledge()
            runCurrent()
            assertEquals(listOf("first", "second"), messenger.values)

            relay.close()
            messenger.acknowledge()
            relay.send("after-close")
            runCurrent()
            assertEquals(listOf("first", "second"), messenger.values)
        } finally {
            relay.close()
            Dispatchers.resetMain()
        }
    }

    @Test
    fun `closing a full queue releases the blocked native sender`() = runTest {
        Dispatchers.setMain(StandardTestDispatcher(testScheduler))
        val messenger = EventMessenger()
        val relay = CoreEventRelay(backgroundScope, MethodChannel(messenger, "core"))
        val sender = Executors.newSingleThreadExecutor()
        try {
            repeat(4) { relay.send("queued-$it") }
            val entered = CountDownLatch(1)
            val send = sender.submit {
                entered.countDown()
                relay.send("overflow")
            }
            assertTrue(entered.await(5, TimeUnit.SECONDS))
            assertThrows(TimeoutException::class.java) {
                send.get(100, TimeUnit.MILLISECONDS)
            }
            relay.close()
            send.get(5, TimeUnit.SECONDS)
            runCurrent()
            assertEquals(emptyList<String>(), messenger.values)
        } finally {
            relay.close()
            sender.shutdownNow()
            Dispatchers.resetMain()
        }
    }
}
