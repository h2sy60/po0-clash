package com.follow.clash.packages

import android.Manifest
import android.content.pm.ApplicationInfo
import android.content.pm.ComponentInfo
import android.content.pm.PackageManager
import android.os.Build
import com.android.tools.smali.dexlib2.dexbacked.DexBackedDexFile
import com.follow.clash.models.InstalledPackage
import java.io.File
import java.util.zip.ZipFile
import kotlin.coroutines.CoroutineContext
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

internal class PackageResolver(
    private val packageManager: PackageManager,
    private val appPackageName: String,
) {
    private val cacheLock = Any()
    private val scanLock = Mutex()

    @Volatile
    private var cachedPackages: List<InstalledPackage>? = null

    @Volatile
    private var cachedChinaPackages: List<String>? = null

    val installedPackages: List<InstalledPackage>
        get() = cachedPackages ?: synchronized(cacheLock) {
            cachedPackages ?: loadPackages().also { cachedPackages = it }
        }

    val isInstalledAppsPermissionSupported: Boolean by lazy {
        runCatching { packageManager.getPermissionInfo(GET_INSTALLED_APPS, 0) }.isSuccess
    }

    fun hasInstalledAppsPermission(): Boolean = !isInstalledAppsPermissionSupported ||
        packageManager.checkPermission(GET_INSTALLED_APPS, appPackageName) ==
        PackageManager.PERMISSION_GRANTED

    fun invalidate() {
        synchronized(cacheLock) {
            cachedPackages = null
            cachedChinaPackages = null
        }
    }

    suspend fun getChinaPackageNames(): List<String> = scanLock.withLock {
        val context = currentCoroutineContext()
        context.ensureActive()
        cachedChinaPackages?.let { return@withLock it }
        val packages = installedPackages
        val names = packages.asSequence()
            .map { it.packageName }
            .filter { packageName ->
                context.ensureActive()
                isChinaPackage(packageName, context)
            }.toList()
        context.ensureActive()
        synchronized(cacheLock) {
            if (cachedPackages === packages) cachedChinaPackages = names
        }
        names
    }

    private fun loadPackages(): List<InstalledPackage> {
        val flags = PackageManager.GET_PERMISSIONS
        val packages = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.getInstalledPackages(
                PackageManager.PackageInfoFlags.of(flags.toLong()),
            )
        } else {
            @Suppress("DEPRECATION")
            packageManager.getInstalledPackages(flags)
        }
        return packages.asSequence()
            .filter { info ->
                info.packageName != appPackageName && info.packageName != ANDROID_PACKAGE_NAME
            }
            .map { info ->
                InstalledPackage(
                    packageName = info.packageName,
                    label = info.applicationInfo?.loadLabel(packageManager)?.toString()
                        ?: info.packageName,
                    system = info.applicationInfo?.let { applicationInfo ->
                        applicationInfo.flags and ApplicationInfo.FLAG_SYSTEM != 0
                    } == true,
                    internet = info.requestedPermissions
                        ?.contains(Manifest.permission.INTERNET) == true,
                    lastUpdateTime = info.lastUpdateTime,
                )
            }.toList()
    }

    private fun isChinaPackage(packageName: String, context: CoroutineContext): Boolean {
        if (ChinaPackageMatcher.isSkipped(packageName)) {
            return false
        }
        if (ChinaPackageMatcher.matchesKnownPrefix(packageName)) {
            return true
        }

        return try {
            val packageInfo = getPackageInfo(packageName)
            context.ensureActive()
            packageInfo.componentNames().any(ChinaPackageMatcher::matchesKnownPrefix) ||
                packageInfo.applicationInfo?.publicSourceDir?.let { scanArchive(it, context) } == true
        } catch (error: CancellationException) {
            throw error
        } catch (_: Exception) {
            false
        }
    }

    private fun getPackageInfo(packageName: String) = if (
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
    ) {
        packageManager.getPackageInfo(
            packageName,
            PackageManager.PackageInfoFlags.of(PACKAGE_INFO_FLAGS.toLong()),
        )
    } else {
        @Suppress("DEPRECATION")
        packageManager.getPackageInfo(packageName, PACKAGE_INFO_FLAGS)
    }

    private fun android.content.pm.PackageInfo.componentNames(): Sequence<String> = sequence {
        yieldAll(services.orEmpty().asSequence().map(ComponentInfo::name))
        yieldAll(activities.orEmpty().asSequence().map(ComponentInfo::name))
        yieldAll(receivers.orEmpty().asSequence().map(ComponentInfo::name))
        yieldAll(providers.orEmpty().asSequence().map(ComponentInfo::name))
    }

    private fun scanArchive(
        sourcePath: String,
        context: CoroutineContext,
    ): Boolean = ZipFile(File(sourcePath)).use { archive ->
        val hasFirebase = archive.entries().asSequence().any { entry ->
            context.ensureActive()
            entry.name.startsWith("firebase-")
        }
        if (hasFirebase) return@use false
        archive.entries().asSequence()
            .filter { entry ->
                context.ensureActive()
                entry.name.startsWith("classes") && entry.name.endsWith(".dex")
            }.any { entry ->
                if (entry.size > MAX_DEX_SIZE_BYTES) {
                    return@any true
                }
                val dexFile = archive.getInputStream(entry).buffered().use { input ->
                    DexBackedDexFile.fromInputStream(null, input)
                }
                dexFile.classes.any { clazz ->
                    context.ensureActive()
                    ChinaPackageMatcher.matchesKnownPrefix(
                        ChinaPackageMatcher.classNameOf(clazz.type),
                    )
                }
            }
    }

    companion object {
        const val GET_INSTALLED_APPS = "com.android.permission.GET_INSTALLED_APPS"

        private const val ANDROID_PACKAGE_NAME = "android"
        private const val MAX_DEX_SIZE_BYTES = 15_000_000L

        private val PACKAGE_INFO_FLAGS = PackageManager.GET_ACTIVITIES or
            PackageManager.GET_SERVICES or
            PackageManager.GET_RECEIVERS or
            PackageManager.GET_PROVIDERS
    }
}
