package com.follow.clash

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class WhitelistBootstrapTest {
    @Test
    fun coldStartWithWhitelistingBootstrapsTheClient() {
        assertTrue(shouldBootstrapWhitelist(enabled = true, hasFlutterEngine = false, running = true))
    }

    @Test
    fun anAttachedClientDoesNotCreateAnotherScheduler() {
        assertFalse(shouldBootstrapWhitelist(enabled = true, hasFlutterEngine = true, running = true))
    }

    @Test
    fun disabledWhitelistingAndFailedOrSupersededStartsDoNotBootstrap() {
        assertFalse(shouldBootstrapWhitelist(enabled = false, hasFlutterEngine = false, running = true))
        assertFalse(shouldBootstrapWhitelist(enabled = true, hasFlutterEngine = false, running = false))
    }

    @Test
    fun oldPo0AndGgySwitchesMigrateWithoutOpeningTheClient() {
        assertTrue(legacyWhitelistEnabled("""{"po0FirewallProps":{"enable":true}}"""))
        assertTrue(legacyWhitelistEnabled("""{"po0FirewallProps":{"enable":false,"ggyEnable":true}}"""))
        assertFalse(legacyWhitelistEnabled("""{"po0FirewallProps":{"enable":false,"ggyEnable":false}}"""))
    }

    @Test
    fun invalidOrAbsentSettingsNeverOptIntoBackgroundStartup() {
        assertFalse(legacyWhitelistEnabled(null))
        assertFalse(legacyWhitelistEnabled("invalid"))
        assertFalse(legacyWhitelistEnabled("""{"po0FirewallProps":{"enable":"true"}}"""))
    }
}
