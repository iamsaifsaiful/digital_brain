package com.iamsaifsaiful.digital_brain

import android.content.Context
import android.hardware.GeomagneticField
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.view.Surface
import android.view.WindowManager
import io.flutter.plugin.common.EventChannel

/**
 * The phone's heading for the compass page: degrees from TRUE north
 * (0–360; the magnetic declination at the place Dart gives is added) and
 * how much to trust it, streamed while the page is open. Rotation vector
 * when the phone has one (gyro-steadied), else the accelerometer with the
 * magnetometer. The heading is where the phone points however it is held:
 * the top edge and the back (camera side) are both projected onto the
 * ground and added, so flat, tilted and upright all give the same,
 * steady direction (getOrientation's azimuth jumps when the phone stands
 * up). Nothing is kept or sent anywhere.
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
    private var declination = 0f

    /** The rotation vector's own error estimate (radians), when the phone gives one. */
    private var rvError = -1f

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
        val a = arguments as? Map<*, *>
        val lat = (a?.get("lat") as? Number)?.toFloat()
        val lon = (a?.get("lon") as? Number)?.toFloat()
        declination = if (lat != null && lon != null) {
            GeomagneticField(lat, lon, 0f, System.currentTimeMillis()).declination
        } else 0f
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
            Sensor.TYPE_ROTATION_VECTOR -> {
                SensorManager.getRotationMatrixFromVector(r, e.values)
                if (e.values.size > 4) rvError = e.values[4]
            }
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
        // Rows of [out] are east, north, up; column 1 is the top edge and
        // column 2 the screen's face. Top edge + back (−face), on the ground.
        val east = out[1] - out[2]
        val north = out[4] - out[5]
        if (east * east + north * north < 1e-4f) return
        var deg = Math.toDegrees(Math.atan2(east.toDouble(), north.toDouble())) + declination
        deg = ((deg % 360.0) + 360.0) % 360.0
        // The fused sensor's own estimate overrides a hopeful magnetometer.
        var acc = accuracy
        if (rvError > 0.35f) acc = minOf(acc, SensorManager.SENSOR_STATUS_ACCURACY_LOW)
        sink?.success(mapOf("heading" to deg, "accuracy" to acc))
    }
}
