package com.follow.clash;

import android.app.Service;
import android.content.Intent;
import android.net.ConnectivityManager;
import android.net.Network;
import android.net.NetworkCapabilities;
import android.os.Bundle;
import android.os.Handler;
import android.os.HandlerThread;
import android.os.IBinder;
import android.os.Message;
import android.os.Messenger;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

public class VpnProbeService extends Service {
    private HandlerThread worker;
    private Messenger messenger;
    private Socket existing;

    @Override
    public void onCreate() {
        super.onCreate();
        worker = new HandlerThread("vpn-app-probe");
        worker.start();
        messenger = new Messenger(new Handler(worker.getLooper(), message -> {
            String result;
            try {
                switch (message.getData().getString("command", "")) {
                    case "open":
                        closeSocket();
                        existing = open();
                        echo(existing);
                        result = "connected";
                        break;
                    case "echo":
                        try {
                            echo(existing);
                            result = "connected";
                        } catch (Exception error) {
                            result = "closed";
                        }
                        break;
                    case "fresh":
                        try (Socket socket = open()) {
                            echo(socket);
                        }
                        result = "connected";
                        break;
                    case "wait-vpn":
                        awaitVpn();
                        result = "vpn";
                        break;
                    default:
                        closeSocket();
                        result = "closed";
                }
            } catch (Exception error) {
                result = error.toString();
            }
            Message reply = Message.obtain();
            Bundle data = new Bundle();
            data.putString("result", result);
            reply.setData(data);
            try {
                message.replyTo.send(reply);
            } catch (Exception ignored) {
            }
            return true;
        }));
    }

    @Override
    public IBinder onBind(Intent intent) {
        return messenger.getBinder();
    }

    private Socket open() throws Exception {
        Socket socket = new Socket();
        socket.connect(new InetSocketAddress("10.0.2.2", 18780), 5000);
        socket.setSoTimeout(5000);
        return socket;
    }

    private void echo(Socket socket) throws Exception {
        byte[] data = "vpn-independent-app\n".getBytes(StandardCharsets.UTF_8);
        socket.getOutputStream().write(data);
        for (byte expected : data) {
            if (socket.getInputStream().read() != (expected & 0xff)) {
                throw new IllegalStateException("Echo connection was closed");
            }
        }
    }

    private void awaitVpn() throws Exception {
        ConnectivityManager manager = getSystemService(ConnectivityManager.class);
        CountDownLatch ready = new CountDownLatch(1);
        ConnectivityManager.NetworkCallback callback = new ConnectivityManager.NetworkCallback() {
            @Override
            public void onCapabilitiesChanged(Network network, NetworkCapabilities capabilities) {
                if (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) ready.countDown();
            }
        };
        manager.registerDefaultNetworkCallback(callback);
        try {
            if (!ready.await(10, TimeUnit.SECONDS)) throw new IllegalStateException("VPN did not become default");
        } finally {
            manager.unregisterNetworkCallback(callback);
        }
    }

    private void closeSocket() {
        if (existing == null) return;
        try {
            existing.close();
        } catch (Exception ignored) {
        }
        existing = null;
    }

    @Override
    public void onDestroy() {
        closeSocket();
        worker.quitSafely();
        super.onDestroy();
    }
}
