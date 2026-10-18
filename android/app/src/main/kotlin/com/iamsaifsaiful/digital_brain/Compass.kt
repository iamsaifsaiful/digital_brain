package com.iamsaifsaiful.digital_brain

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.view.Surface
import android.view.WindowManager
import io.flutter.plugin.common.EventChannel

/**
 * The phone's heading for the compass page: degrees from magnetic north
 * (0–360) and how much to trust it, streamed while the page is open.
 * Rotation vector when the phone has one (gyro-steadied), else the
 * accelerometer with the magnetometer. Nothing is kept or sent anywhere.
 */
class Compass(private val context: Context) : EventChannel.StreamHandler, SensorEventListener {
    private val sm = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private var sink: EventChannel.EventSink? = null
    private val gravity = FloatArray(3)
    private val geomag = FloatArray(3)
    private var haveG = false
    private var haveM = false
    private var accuracy = SensorManager.SENSOR_STATUS_ACCURACY_MEDIUM
    private var lastSent = 0L

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
        val rv = sm.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
        val mag = sm.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD)
        if (rv == null && (mag == null || sm.getDefaultSensor(Sensor.TYPE_ACCELEROMETER) == null)) {
            events?.success(mapOf("none" to true))
            return
        }
        if (rv != null) {
            sm.registerListener(this, rv, SensorManager.SENSOR_DELAY_UI)
        } else {
            sm.registerListener(this, sm.getDefaultSensor(Sensor.TYPE_ACCELEROMETER), SensorManager.SENSOR_DELAY_UI)
        }
        // The magnetometer's own accuracy tells when the phone needs a figure-8.
        if (mag != null) sm.registerListener(this, mag, SensorManager.SENSOR_DELAY_UI)
    }

    override fun onCancel(arguments: Any?) {
        sm.unregisterListener(this)
        sink = null
        haveG = false
        haveM = false
    }

    override fun onAccuracyChanged(sensor: Sensor?, acc: Int) {
        if (sensor?.type == Sensor.TYPE_MAGNETIC_FIELD) accuracy = acc
    }

    override fun onSensorChanged(e: SensorEvent) {
        val r = FloatArray(9)
        when (e.sensor.type) {
            Sensor.TYPE_ROTATION_VECTOR -> SensorManager.getRotationMatrixFromVector(r, e.values)
            Sensor.TYPE_ACCELEROMETER -> {
                for (i in 0..2) gravity[i] = 0.85f * gravity[i] + 0.15f * e.values[i]
                haveG = true
                if (!haveM || !SensorManager.getRotationMatrix(r, null, gravity, geomag)) return
            }
            Sensor.TYPE_MAGNETIC_FIELD -> {
                for (i in 0..2) geomag[i] = 0.85f * geomag[i] + 0.15f * e.values[i]
                haveM = true
                return
            }
            else -> return
        }
        val now = System.currentTimeMillis()
        if (now - lastSent < 40) return
        lastSent = now
        // The screen may be turned: measure along its top edge.
        val out = FloatArray(9)
        @Suppress("DEPRECATION")
        val rot = (context.getSystemService(Context.WINDOW_SERVICE) as WindowManager).defaultDisplay.rotation
        when (rot) {
            Surface.ROTATION_90 -> SensorManager.remapCoordinateSystem(r, SensorManager.AXIS_Y, SensorManager.AXIS_MINUS_X, out)
            Surface.ROTATION_180 -> SensorManager.remapCoordinateSystem(r, SensorManager.AXIS_MINUS_X, SensorManager.AXIS_MINUS_Y, out)
            Surface.ROTATION_270 -> SensorManager.remapCoordinateSystem(r, SensorManager.AXIS_MINUS_Y, SensorManager.AXIS_X, out)
            else -> System.arraycopy(r, 0, out, 0, 9)
        }
        val o = FloatArray(3)
        SensorManager.getOrientation(out, o)
        var deg = Math.toDegrees(o[0].toDouble())
        if (deg < 0) deg += 360.0
        sink?.success(mapOf("heading" to deg, "accuracy" to accuracy))
    }
}
