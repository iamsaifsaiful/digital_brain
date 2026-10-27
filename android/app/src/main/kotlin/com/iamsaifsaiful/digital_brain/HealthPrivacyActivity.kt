package com.iamsaifsaiful.digital_brain

import android.app.Activity
import android.os.Bundle
import android.util.TypedValue
import android.widget.ScrollView
import android.widget.TextView

/**
 * What Health Connect shows when someone taps "privacy policy" for this app
 * (Android 13 and older: ACTION_SHOW_PERMISSIONS_RATIONALE; 14 and newer:
 * the ViewPermissionUsageActivity alias). Plain text, no network.
 */
class HealthPrivacyActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val pad = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 20f, resources.displayMetrics).toInt()
        val text = TextView(this).apply {
            setPadding(pad, pad, pad, pad)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            setLineSpacing(0f, 1.3f)
            text = getString(R.string.health_privacy)
        }
        setContentView(ScrollView(this).apply { addView(text) })
        title = getString(R.string.health_privacy_title)
    }
}
