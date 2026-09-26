package com.busbuddy.app

import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var voiceChannel: BusBuddyVoiceChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // A re-attached engine gets a fresh channel; retire the previous one so
        // its AudioRecord/AudioTrack/TextToSpeech handles are released.
        voiceChannel?.dispose()
        val channel = BusBuddyVoiceChannel(applicationContext, this)
        channel.attach(flutterEngine)
        voiceChannel = channel
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
        val showRationale = permissions.isNotEmpty() &&
            ActivityCompat.shouldShowRequestPermissionRationale(this, permissions[0])
        voiceChannel?.handlePermissionResult(requestCode, granted, showRationale)
    }

    override fun onDestroy() {
        voiceChannel?.dispose()
        voiceChannel = null
        super.onDestroy()
    }
}
