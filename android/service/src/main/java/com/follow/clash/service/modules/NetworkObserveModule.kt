package com.follow.clash.service.modules

import android.app.Service
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkCapabilities.TRANSPORT_SATELLITE
import android.net.NetworkCapabilities.TRANSPORT_USB
import android.net.NetworkRequest
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.content.getSystemService
import com.follow.clash.core.Core
import java.net.Inet4Address
import java.net.Inet6Address
import java.net.InetAddress

private data class NetworkInfo(
    var losingUntilMillis: Long = 0,
    var dnsList: List<InetAddress> = emptyList(),
    var capabilities: NetworkCapabilities? = null,
) {
    val priorityPenalty: Int
        get() = if (losingUntilMillis > System.currentTimeMillis()) 10 else 0
}

internal class NetworkObserveModule(private val service: Service) : ServiceModule {

    private val networkInfos = mutableMapOf<Network, NetworkInfo>()
    private var active = false
    private val connectivity by lazy {
        service.getSystemService<ConnectivityManager>()
    }
    private val mainHandler = Handler(Looper.getMainLooper())
    private var currentDnsList = listOf<String>()

    private val request = NetworkRequest.Builder().apply {
        addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)
        addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            addCapability(NetworkCapabilities.NET_CAPABILITY_FOREGROUND)
        }
        addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_RESTRICTED)
    }.build()

    private val callback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) = whileActive {
            networkInfos[network] = NetworkInfo(
                capabilities = connectivity?.getNetworkCapabilities(network),
            )
            updateDns()
        }

        override fun onLosing(network: Network, maxMsToLive: Int) = whileActive {
            val info = networkInfos[network] ?: return@whileActive
            info.losingUntilMillis = System.currentTimeMillis() + maxMsToLive
            updateDns()
            if (maxMsToLive > 0) {
                mainHandler.postDelayed({
                    whileActive {
                        if (networkInfos.containsKey(network)) {
                            updateDns()
                        }
                    }
                }, maxMsToLive.toLong() + 50)
            }
        }

        override fun onLost(network: Network) = whileActive {
            networkInfos.remove(network)
            updateDns()
        }

        override fun onLinkPropertiesChanged(
            network: Network,
            linkProperties: LinkProperties,
        ) = whileActive {
            networkInfos[network]?.dnsList = linkProperties.dnsServers
            updateDns()
        }

        override fun onCapabilitiesChanged(
            network: Network,
            capabilities: NetworkCapabilities,
        ) = whileActive {
            networkInfos[network]?.capabilities = capabilities
            updateDns()
        }
    }

    override fun start() {
        synchronized(this) {
            if (active) return
            active = true
        }
        try {
            updateDns()
            connectivity?.registerNetworkCallback(request, callback)
        } catch (error: Exception) {
            clearNetworks()
            throw error
        }
    }

    private inline fun whileActive(action: () -> Unit) {
        synchronized(this) {
            if (active) action()
        }
    }

    private fun networkPriority(entry: Map.Entry<Network, NetworkInfo>): Int {
        val capabilities = entry.value.capabilities
        return when {
            capabilities == null -> 100
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN) -> 90
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> 0
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> 1
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                capabilities.hasTransport(TRANSPORT_USB) -> 2

            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_BLUETOOTH) -> 3
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> 4
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.VANILLA_ICE_CREAM &&
                capabilities.hasTransport(TRANSPORT_SATELLITE) -> 5

            else -> 20
        } + entry.value.priorityPenalty
    }

    @Synchronized
    private fun updateDns() {
        val dnsList = networkInfos.asSequence()
            .minByOrNull(::networkPriority)
            ?.value
            ?.dnsList
            .orEmpty()
            .map { address -> address.asSocketAddressText(DNS_PORT) }
            .distinct()
        if (dnsList == currentDnsList) {
            return
        }
        currentDnsList = dnsList
        Core.updateDNS(dnsList.joinToString(","))
    }

    override fun stop() {
        try {
            clearNetworks()
        } finally {
            connectivity?.unregisterNetworkCallback(callback)
        }
    }

    @Synchronized
    private fun clearNetworks() {
        active = false
        mainHandler.removeCallbacksAndMessages(null)
        networkInfos.clear()
        updateDns()
    }
}

private const val DNS_PORT = 53

private fun InetAddress.asSocketAddressText(port: Int): String = when (this) {
    is Inet6Address -> "[$hostAddress]:$port"
    is Inet4Address -> "$hostAddress:$port"
    else -> error("Unsupported address type: ${javaClass.name}")
}
