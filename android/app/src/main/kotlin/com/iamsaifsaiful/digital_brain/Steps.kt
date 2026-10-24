package com.iamsaifsaiful.digital_brain

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Steps for স্বাস্থ্য: the phone's own step counter (counted by the phone
 * all day, even with the app closed; it starts again from 0 when the phone
 * restarts). Dart reads the running count and works out today's steps on
 * the phone. Nothing is kept here or sent anywhere.
 */
object Steps {
    private const val REQUEST = 4711

    private fun allowed(a: Context) = Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
        a.checkSelfPermission(Manifest.permission.ACTIVITY_RECOGNITION) == PackageManager.PERMISSION_GRANTED

    fun handle(a: Activity, call: MethodCall, result: MethodChannel.Result) {
        val sm = a.getSystemService(Context.SENSOR_SERVICE) as SensorManager
        val sensor = sm.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
        when (call.method) {
            "status" -> result.success(mapOf("sensor" to (sensor != null), "allowed" to allowed(a)))
            "ask" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && !allowed(a)) {
                    a.requestPermissions(arrayOf(Manifest.permission.ACTIVITY_RECOGNITION), REQUEST)
                }
                result.success(null)
            }
            "read" -> {
                if (sensor == null || !allowed(a)) {
                    result.success(null)
                    return
                }
                var done = false
                val main = Handler(Looper.getMainLooper())
                val listener = object : SensorEventListener {
                    override fun onSensorChanged(e: SensorEvent) {
                        if (done) return
                        done = true
                        sm.unregisterListener(this)
                        result.success(e.values[0].toDouble())
                    }
                    override fun onAccuracyChanged(s: Sensor?, acc: Int) {}
                }
                sm.registerListener(listener, sensor, SensorManager.SENSOR_DELAY_NORMAL)
                // Some phones send the count only on the next step: give up after 4 s.
                main.postDelayed({
                    if (!done) {
                        done = true
                        sm.unregisterListener(listener)
                        result.success(null)
                    }
                }, 4000)
            }
            else -> result.notImplemented()
        }
    }
}
