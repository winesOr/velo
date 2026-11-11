package com.edde746.plezy

import android.app.Activity
import android.app.KeyguardManager
import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.content.FileProvider
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/** Only hands verified self-update APKs to Android's user-confirmed installer. */
internal class AppUpdateChannel(private val activity: Activity) {
  private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
  private var channel: MethodChannel? = null

  fun attach(messenger: BinaryMessenger) {
    channel = MethodChannel(messenger, "com.wines.velo/app_update").also {
      it.setMethodCallHandler(::onMethodCall)
    }
  }

  fun dispose() {
    channel?.setMethodCallHandler(null)
    channel = null
    scope.cancel()
  }

  private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "getDeviceInfo" -> {
        val installed = installedPackage()
        result.success(
          mapOf(
            "supportedAbis" to Build.SUPPORTED_ABIS.toList(),
            "packageName" to activity.packageName,
            "versionCode" to versionCode(installed)
          )
        )
      }
      "canInstallPackages" -> result.success(canInstallPackages())
      "openInstallPermissionSettings" -> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
          result.success(true)
          return
        }
        try {
          requireForeground()
          activity.startActivity(
            Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:${activity.packageName}"))
          )
          result.success(true)
        } catch (error: UpdateFailure) {
          result.error(error.code, error.message, null)
        } catch (_: Exception) {
          result.error("PERMISSION_SETTINGS_UNAVAILABLE", "Cannot open installation permission settings", null)
        }
      }
      "installApk" -> {
        val path = call.argument<String>("path")
        scope.launch {
          try {
            if (!canInstallPackages()) {
              throw UpdateFailure("INSTALL_PERMISSION_REQUIRED", "Installation permission is required")
            }
            // Certificate parsing can read a large APK; keep it off the UI thread.
            val apk = withContext(Dispatchers.IO) { validatedApk(path) }
            val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.fileprovider", apk)
            // Recheck immediately before launch: the user may have left or locked
            // the phone while certificate parsing was running off the main thread.
            requireForeground()
            activity.startActivity(
              Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                clipData = ClipData.newRawUri("APK", uri)
              }
            )
            // Android owns the confirmation and installation result from here.
            result.success(true)
          } catch (_: CancellationException) {
            result.error("ACTIVITY_DESTROYED", "The application activity is no longer available", null)
          } catch (error: UpdateFailure) {
            result.error(error.code, error.message, null)
          } catch (_: ActivityNotFoundException) {
            result.error("INSTALLER_UNAVAILABLE", "No APK installer is available", null)
          } catch (_: Exception) {
            result.error("INSTALL_FAILED", "Cannot open the APK installer", null)
          }
        }
      }
      else -> result.notImplemented()
    }
  }

  private fun canInstallPackages(): Boolean = Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
    activity.packageManager.canRequestPackageInstalls()

  private fun requireForeground() {
    if (activity.isFinishing || activity.isDestroyed) {
      throw UpdateFailure("ACTIVITY_DESTROYED", "The application activity is no longer available")
    }
    if (!canLaunchUpdateUi(activity)) {
      throw UpdateFailure("ACTIVITY_NOT_RESUMED", "Return to the application to install the update")
    }
  }

  companion object {
    internal fun canLaunchUpdateUi(activity: Activity): Boolean {
      val lifecycle = (activity as? LifecycleOwner)?.lifecycle ?: return false
      val power = activity.getSystemService(PowerManager::class.java) ?: return false
      val keyguard = activity.getSystemService(KeyguardManager::class.java) ?: return false
      return lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED) &&
        activity.hasWindowFocus() &&
        power.isInteractive &&
        !keyguard.isKeyguardLocked
    }
  }

  @Suppress("DEPRECATION")
  private fun signingFlags(): Int = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
    PackageManager.GET_SIGNING_CERTIFICATES
  } else {
    PackageManager.GET_SIGNATURES
  }

  @Suppress("DEPRECATION")
  private fun installedPackage(): PackageInfo = activity.packageManager.getPackageInfo(activity.packageName, signingFlags())

  @Suppress("DEPRECATION")
  private fun validatedApk(path: String?): File {
    if (path.isNullOrBlank()) throw UpdateFailure("INVALID_APK_PATH", "Missing update APK")
    val apk = File(path).canonicalFile
    if (!AppUpdateValidation.isUpdateFile(activity.cacheDir, apk)) {
      throw UpdateFailure("INVALID_APK_PATH", "The APK must be inside the application's update cache")
    }
    val archive = activity.packageManager.getPackageArchiveInfo(apk.path, signingFlags())
      ?: throw UpdateFailure("INVALID_APK", "The update is not a readable APK")
    val installed = installedPackage()
    if (archive.packageName != activity.packageName) {
      throw UpdateFailure("PACKAGE_MISMATCH", "The APK belongs to a different application")
    }
    if (versionCode(archive) <= versionCode(installed)) {
      throw UpdateFailure("VERSION_NOT_NEWER", "The APK must have a newer version code")
    }
    val compatible = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
      val current = installed.signingInfo
      val candidate = archive.signingInfo
      current != null &&
        candidate != null &&
        AppUpdateValidation.hasCompatibleSigners(
          current.apkContentsSigners.map { it.toCharsString() }.toSet(),
          candidate.apkContentsSigners.map { it.toCharsString() }.toSet(),
          if (candidate.hasMultipleSigners()) emptySet() else candidate.signingCertificateHistory.orEmpty().map { it.toCharsString() }.toSet()
        )
    } else {
      AppUpdateValidation.hasCompatibleSigners(
        installed.signatures.orEmpty().map { it.toCharsString() }.toSet(),
        archive.signatures.orEmpty().map { it.toCharsString() }.toSet(),
        emptySet()
      )
    }
    if (!compatible) throw UpdateFailure("SIGNATURE_MISMATCH", "The APK signing certificate does not match this installation")
    return apk
  }

  @Suppress("DEPRECATION")
  private fun versionCode(info: PackageInfo): Long = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
    info.longVersionCode
  } else {
    info.versionCode.toLong()
  }

  private class UpdateFailure(val code: String, message: String) : Exception(message)
}

internal object AppUpdateValidation {
  fun isUpdateFile(cache: File, candidate: File): Boolean {
    val root = File(cache, "updates").canonicalFile
    val canonical = candidate.canonicalFile
    return canonical.path.startsWith(root.path + File.separator) && canonical.isFile && canonical.extension == "apk"
  }

  fun hasCompatibleSigners(installed: Set<String>, candidate: Set<String>, candidateHistory: Set<String>): Boolean {
    if (installed.isEmpty() || candidate.isEmpty()) return false
    if (installed == candidate) return true
    // Only forward rotation: the candidate's platform-verified lineage must include
    // the currently installed signer. Multiple signers require an exact set match.
    return installed.size == 1 && candidate.size == 1 && candidateHistory.containsAll(installed)
  }
}
