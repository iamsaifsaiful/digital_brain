package com.iamsaifsaiful.digital_brain

import android.app.Activity
import androidx.activity.ComponentActivity
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.IntentSenderRequest
import androidx.activity.result.contract.ActivityResultContracts
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.appupdate.AppUpdateOptions
import com.google.android.play.core.install.model.AppUpdateType
import com.google.android.play.core.install.model.UpdateAvailability
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * A newer version on Google Play (owner, 31 Oct): the app shows its own
 * "নতুন সংস্করণ এসেছে" page (lib/screens/update_screen.dart) and, when the
 * user agrees, Google Play's update runs inside the app (an "immediate"
 * update: Play downloads and installs it, then the app starts again). Only an
 * app installed from Google Play can update this way; the downloaded APK is
 * told "none" and nothing is shown.
 *
 * Channel "my_assistant/update": "check" → {available, inProgress,
 * versionCode, staleDays}; "start" → "ok" / "cancelled" / "failed" / "none".
 * Made when the activity is (the result launcher must be registered before
 * it starts); the Play manager itself only on first use.
 */
class PlayUpdate(private val activity: ComponentActivity) {
    private val manager by lazy { AppUpdateManagerFactory.create(activity) }
    private var pending: MethodChannel.Result? = null

    private val launcher: ActivityResultLauncher<IntentSenderRequest> =
        activity.registerForActivityResult(ActivityResultContracts.StartIntentSenderForResult()) { r ->
            val p = pending
            pending = null
            p?.success(
                when (r.resultCode) {
                    Activity.RESULT_OK -> "ok"
                    Activity.RESULT_CANCELED -> "cancelled"
                    else -> "failed"
                }
            )
        }

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "check" -> try {
                manager.appUpdateInfo
                    .addOnSuccessListener { info ->
                        result.success(
                            mapOf(
                                "available" to (info.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE &&
                                    info.isUpdateTypeAllowed(AppUpdateType.IMMEDIATE)),
                                "inProgress" to (info.updateAvailability() == UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS),
                                "versionCode" to info.availableVersionCode(),
                                "staleDays" to (info.clientVersionStalenessDays() ?: -1),
                            )
                        )
                    }
                    .addOnFailureListener { result.success(mapOf("available" to false)) }
            } catch (_: Exception) {
                result.success(mapOf("available" to false))
            }
            "start" -> try {
                manager.appUpdateInfo
                    .addOnSuccessListener { info ->
                        val a = info.updateAvailability()
                        if (a != UpdateAvailability.UPDATE_AVAILABLE && a != UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS) {
                            result.success("none")
                            return@addOnSuccessListener
                        }
                        pending?.success("failed")
                        pending = result
                        val started = try {
                            manager.startUpdateFlowForResult(info, launcher, AppUpdateOptions.newBuilder(AppUpdateType.IMMEDIATE).build())
                        } catch (_: Exception) {
                            false
                        }
                        if (!started) {
                            pending = null
                            result.success("failed")
                        }
                    }
                    .addOnFailureListener { result.success("failed") }
            } catch (_: Exception) {
                result.success("failed")
            }
            else -> result.notImplemented()
        }
    }
}
