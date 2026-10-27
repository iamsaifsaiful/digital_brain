package com.iamsaifsaiful.digital_brain

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.activity.result.ActivityResultLauncher
import androidx.fragment.app.FragmentActivity
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.request.AggregateRequest
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.time.Instant
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * Health Connect, read only (owner, 27 Oct): steps, sleep and exercise.
 * Nothing is written, and what is read goes only to the app's own screens
 * on this phone (lib/services/health_connect.dart).
 */
object HealthConnect {
    private const val PROVIDER = "com.google.android.apps.healthdata"

    val permissions = setOf(
        HealthPermission.getReadPermission(StepsRecord::class),
        HealthPermission.getReadPermission(SleepSessionRecord::class),
        HealthPermission.getReadPermission(ExerciseSessionRecord::class),
    )

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var launcher: ActivityResultLauncher<Set<String>>? = null
    private var asking: MethodChannel.Result? = null

    /** Called from MainActivity.onCreate (before it starts), as the result API needs. */
    fun register(a: FragmentActivity) {
        launcher = a.registerForActivityResult(PermissionController.createRequestPermissionResultContract()) { given ->
            asking?.success(given.containsAll(permissions))
            asking = null
        }
    }

    private fun status(c: Context): String {
        // Health Connect itself runs on Android 9 (API 28) and newer.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return "unsupported"
        return when (HealthConnectClient.getSdkStatus(c, PROVIDER)) {
            HealthConnectClient.SDK_AVAILABLE -> "available"
            HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED -> "not_installed"
            // Android 9–13 without the app; on 14+ it is part of the phone.
            else -> if (Build.VERSION.SDK_INT < 34) "not_installed" else "unsupported"
        }
    }

    private fun range(call: MethodCall): TimeRangeFilter {
        val from = (call.argument<Number>("from") ?: 0).toLong()
        val to = (call.argument<Number>("to") ?: System.currentTimeMillis()).toLong()
        return TimeRangeFilter.between(Instant.ofEpochMilli(from), Instant.ofEpochMilli(to))
    }

    fun handle(a: FragmentActivity, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "status" -> result.success(status(a))
            "install" -> {
                val market = Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=$PROVIDER&url=healthconnect%3A%2F%2Fonboarding"))
                    .setPackage("com.android.vending")
                try {
                    a.startActivity(market)
                } catch (_: ActivityNotFoundException) {
                    a.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://play.google.com/store/apps/details?id=$PROVIDER")))
                }
                result.success(null)
            }
            else -> {
                if (status(a) != "available") {
                    result.success(if (call.method == "granted" || call.method == "request") false else null)
                    return
                }
                val client = HealthConnectClient.getOrCreate(a)
                scope.launch {
                    try {
                        when (call.method) {
                            "granted" -> result.success(client.permissionController.getGrantedPermissions().containsAll(permissions))
                            "request" -> {
                                if (client.permissionController.getGrantedPermissions().containsAll(permissions)) {
                                    result.success(true)
                                } else {
                                    val l = launcher
                                    if (l == null || asking != null) result.success(false) else {
                                        asking = result
                                        l.launch(permissions)
                                    }
                                }
                            }
                            "steps" -> {
                                val r = client.aggregate(AggregateRequest(metrics = setOf(StepsRecord.COUNT_TOTAL), timeRangeFilter = range(call)))
                                result.success(r[StepsRecord.COUNT_TOTAL])
                            }
                            "sleep" -> {
                                val r = client.readRecords(ReadRecordsRequest(SleepSessionRecord::class, timeRangeFilter = range(call)))
                                result.success(r.records.map { s ->
                                    mapOf(
                                        "id" to s.metadata.id,
                                        "start" to s.startTime.toEpochMilli(),
                                        "end" to s.endTime.toEpochMilli(),
                                        "stages" to s.stages.map { mapOf("stage" to it.stage, "start" to it.startTime.toEpochMilli(), "end" to it.endTime.toEpochMilli()) },
                                    )
                                })
                            }
                            "exercise" -> {
                                val r = client.readRecords(ReadRecordsRequest(ExerciseSessionRecord::class, timeRangeFilter = range(call)))
                                result.success(r.records.map { s ->
                                    mapOf("id" to s.metadata.id, "start" to s.startTime.toEpochMilli(), "end" to s.endTime.toEpochMilli(), "type" to s.exerciseType)
                                })
                            }
                            else -> result.notImplemented()
                        }
                    } catch (e: Exception) {
                        // No permission, or Health Connect busy: Dart treats it as "nothing to read".
                        result.error("hc", e.javaClass.simpleName, null)
                    }
                }
            }
        }
    }
}
