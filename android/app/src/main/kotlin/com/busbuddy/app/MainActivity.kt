package com.busbuddy.app

import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var voiceChannel: BusBuddyVoiceChannel? = null
    private var locationShareChannel: BusBuddyLocationShareChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // A re-attached engine gets a fresh channel; retire the previous one so
        // its AudioRecord/AudioTrack/TextToSpeech handles are released.
        voiceChannel?.dispose()
        locationShareChannel?.dispose()
        val channel = BusBuddyVoiceChannel(applicationContext, this)
        channel.attach(flutterEngine)
        voiceChannel = channel
        val locationChannel = BusBuddyLocationShareChannel(applicationContext, this)
        locationChannel.attach(flutterEngine)
        locationShareChannel = locationChannel
    }

    /** Forwards the `RECORD_AUDIO` prompt result to the waiting voice channel. */
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        val granted = grantResults.isNotEmpty() &&
            grantResults.all { it == PackageManager.PERMISSION_GRANTED }
        val showRationale = permissions.indices.any { index ->
            grantResults.getOrNull(index) != PackageManager.PERMISSION_GRANTED &&
                ActivityCompat.shouldShowRequestPermissionRationale(this, permissions[index])
        }
        voiceChannel?.handlePermissionResult(requestCode, granted, showRationale)
        locationShareChannel?.handlePermissionResult(
            requestCode,
            permissions,
            grantResults,
            showRationale,
        )
    }

    override fun onDestroy() {
        voiceChannel?.dispose()
        voiceChannel = null
        locationShareChannel?.dispose()
        locationShareChannel = null
        super.onDestroy()
    }
}
