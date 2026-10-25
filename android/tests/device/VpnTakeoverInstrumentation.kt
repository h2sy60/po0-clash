package com.follow.clash

import android.app.Activity
import android.app.Instrumentation
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.Message
import android.os.Messenger
import com.follow.clash.common.AccessControlMode
import com.follow.clash.core.Core
import com.follow.clash.service.ServiceConfig
import com.follow.clash.service.VpnService
import com.follow.clash.service.models.AccessControlProps
import com.follow.clash.service.models.VpnOptions
import java.io.DataInputStream
import java.io.File
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetSocketAddress
import java.net.Socket
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

class VpnTakeoverInstrumentation : Instrumentation() {
    override fun onCreate(arguments: Bundle?) {
        super.onCreate(arguments)
        start()
    }

    override fun onStart() {
        Thread {
            val result = Bundle()
            try {
                runTakeover()
                result.putString("stream", "VPN takeover: Core TCP/UDP, independent app reconnection, and explicit bypass passed\n")
                finish(Activity.RESULT_OK, result)
            } catch (error: Throwable) {
                result.putString("stream", error.stackTraceToString())
                finish(Activity.RESULT_CANCELED, result)
            }
        }.start()
    }

    private fun runTakeover() {
        check(android.net.VpnService.prepare(targetContext) == null) { "Grant ACTIVATE_VPN before running" }
        val home = targetContext.filesDir
        File(home, "config.yaml").writeText(
            "mixed-port: 17890\nmode: direct\nlog-level: debug\nipv6: true\ndns:\n  enable: false\n",
        )
        val setupDone = CountDownLatch(1)
        var setupError: String? = null
        Core.quickSetup(
            "{\"home-dir\":\"${home.path}\",\"version\":${android.os.Build.VERSION.SDK_INT}}",
            "{}",
        ) { value ->
            setupError = value
            setupDone.countDown()
        }
        check(setupDone.await(30, TimeUnit.SECONDS)) { "Core setup timed out" }
        check(setupError.isNullOrEmpty()) { "Core setup failed: $setupError" }
        val connected = CountDownLatch(1)
        var vpn: VpnService? = null
        val binding = object : ServiceConnection {
            override fun onServiceConnected(name: ComponentName, binder: IBinder) {
                vpn = (binder as VpnService.LocalBinder).service
                connected.countDown()
            }

            override fun onServiceDisconnected(name: ComponentName) = Unit
        }
        check(targetContext.bindService(Intent(targetContext, VpnService::class.java), binding, Context.BIND_AUTO_CREATE))
        try {
            check(connected.await(10, TimeUnit.SECONDS)) { "VPN binding timed out" }
            ServiceConfig.updateVpnOptions(
                VpnOptions(
                    enable = true,
                    port = 17890,
                    ipv6 = false,
                    dnsHijacking = false,
                    accessControlProps = AccessControlProps(false, AccessControlMode.REJECT_SELECTED, emptyList(), emptyList()),
                    allowBypass = false,
                    systemProxy = false,
                    bypassDomain = emptyList(),
                    stack = "mixed",
                    routeAddress = emptyList(),
                ),
            )
            requireNotNull(vpn).start()
            openProxySocket().use { upstream ->
                withProxyDatagram { packet ->
                    echo(upstream)
                    echo(packet)
                    Core.forceGC()
                    echo(upstream)
                    echo(packet)
                    repeat(3) {
                        Socket().use { fresh ->
                            fresh.connect(InetSocketAddress("10.0.2.2", 18780), 5_000)
                            fresh.soTimeout = 5_000
                            echo(fresh)
                        }
                    }
                }
            }
            requireNotNull(vpn).stop()
            testIndependentApp(requireNotNull(vpn))
        } finally {
            vpn?.stop()
            targetContext.unbindService(binding)
        }
    }

    private fun testIndependentApp(vpn: VpnService) {
        val bound = CountDownLatch(1)
        var remote: Messenger? = null
        val binding = object : ServiceConnection {
            override fun onServiceConnected(name: ComponentName, binder: IBinder) {
                remote = Messenger(binder)
                bound.countDown()
            }

            override fun onServiceDisconnected(name: ComponentName) = Unit
        }
        val intent = Intent().setComponent(ComponentName(context.packageName, VpnProbeService::class.java.name))
        check(targetContext.bindService(intent, binding, Context.BIND_AUTO_CREATE))
        try {
            check(bound.await(10, TimeUnit.SECONDS)) { "Independent app did not bind" }
            fun command(value: String): String? {
                val done = CountDownLatch(1)
                var result: String? = null
                val reply = Messenger(Handler(Looper.getMainLooper()) { message ->
                    result = message.data.getString("result")
                    done.countDown()
                    true
                })
                requireNotNull(remote).send(Message.obtain().apply {
                    data = Bundle().apply { putString("command", value) }
                    replyTo = reply
                })
                check(done.await(15, TimeUnit.SECONDS)) { "Independent app command timed out: $value" }
                return result
            }
            for (policyVersion in listOf(1, 0)) {
                check(command("open") == "connected")
                ServiceConfig.updateVpnOptions(requireNotNull(ServiceConfig.vpnOptions).copy(
                    allowBypass = true,
                    bypassPolicyVersion = policyVersion,
                ))
                vpn.start()
                check(command("wait-vpn") == "vpn")
                val expected = if (policyVersion == 1) "connected" else "closed"
                check(command("echo") == expected) { "Stale connection retained with bypass policy $policyVersion" }
                check(command("fresh") == "connected") { "Fresh app connection did not pass through VPN" }
                command("close")
                vpn.stop()
            }
        } finally {
            targetContext.unbindService(binding)
        }
    }

    private fun echo(socket: Socket) {
        val expected = "po0-vpn-takeover\n".toByteArray()
        socket.getOutputStream().write(expected)
        val actual = ByteArray(expected.size)
        var offset = 0
        while (offset < actual.size) {
            val count = socket.getInputStream().read(actual, offset, actual.size - offset)
            check(count > 0) { "Connection closed during takeover" }
            offset += count
        }
        check(expected.contentEquals(actual)) { "Connection payload changed during takeover" }
    }

    private fun openProxySocket(): Socket {
        val socket = Socket()
        socket.connect(InetSocketAddress("127.0.0.1", 17890), 5_000)
        socket.soTimeout = 5_000
        socket.getOutputStream().write("CONNECT 10.0.2.2:18780 HTTP/1.1\r\nHost: 10.0.2.2:18780\r\n\r\n".toByteArray())
        val header = StringBuilder()
        while (!header.endsWith("\r\n\r\n")) {
            val value = socket.getInputStream().read()
            check(value >= 0 && header.length < 8192) { "Mixed proxy did not accept CONNECT" }
            header.append(value.toChar())
        }
        check(header.startsWith("HTTP/1.1 200")) { "Mixed proxy rejected CONNECT: $header" }
        return socket
    }

    private fun echo(socket: DatagramSocket) {
        val expected = "po0-vpn-takeover".toByteArray()
        val header = byteArrayOf(0, 0, 0, 1, 10, 0, 2, 2, 0x49, 0x5c)
        val request = header + expected
        socket.send(DatagramPacket(request, request.size))
        val received = DatagramPacket(ByteArray(1024), 1024)
        socket.receive(received)
        check(request.contentEquals(received.data.copyOf(received.length))) { "UDP payload changed during takeover" }
    }

    private fun withProxyDatagram(block: (DatagramSocket) -> Unit) {
        Socket().use { control ->
            control.connect(InetSocketAddress("127.0.0.1", 17890), 5_000)
            control.soTimeout = 5_000
            val input = DataInputStream(control.getInputStream())
            val output = control.getOutputStream()
            output.write(byteArrayOf(5, 1, 0))
            check(input.readUnsignedByte() == 5 && input.readUnsignedByte() == 0) { "SOCKS authentication failed" }
            output.write(byteArrayOf(5, 3, 0, 1, 0, 0, 0, 0, 0, 0))
            check(input.readUnsignedByte() == 5 && input.readUnsignedByte() == 0 &&
                input.readUnsignedByte() == 0 && input.readUnsignedByte() == 1) {
                "SOCKS UDP association failed"
            }
            input.readFully(ByteArray(4))
            val port = input.readUnsignedShort()
            DatagramSocket().use { packet ->
                packet.connect(InetSocketAddress("127.0.0.1", port))
                packet.soTimeout = 5_000
                block(packet)
            }
        }
    }
}
