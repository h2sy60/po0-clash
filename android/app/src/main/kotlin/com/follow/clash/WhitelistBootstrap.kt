package com.follow.clash

import com.google.gson.JsonElement
import com.google.gson.JsonParser

internal fun shouldBootstrapWhitelist(
    enabled: Boolean,
    hasFlutterEngine: Boolean,
    running: Boolean,
): Boolean = enabled && !hasFlutterEngine && running

internal fun legacyWhitelistEnabled(config: String?): Boolean = try {
    val props = JsonParser.parseString(config ?: "{}").asJsonObject
        .getAsJsonObject("po0FirewallProps")
    fun enabled(value: JsonElement?): Boolean = value?.takeIf {
        it.isJsonPrimitive && it.asJsonPrimitive.isBoolean
    }?.asBoolean == true
    enabled(props?.get("enable")) || enabled(props?.get("ggyEnable"))
} catch (_: Exception) {
    false
}
