package com.busbuddy.app

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Foreground-only one-shot location, Android share chooser, and dialer intents. */
class BusBuddyLocationShareChannel(
    private val context: Context,
    private val activity: Activity,
) : MethodChannel.MethodCallHandler {
    companion object {
        private const val CHANNEL = "busbuddy/location_share"
        private const val LOCATION_REQUEST_CODE = 0xB0B2
        private const val PERMISSION_PREFS = "busbuddy_location_permissions"
        private const val ASKED_LOCATION = "asked_location"
        private const val LOCATION_TIMEOUT_MS = 15_000L
        private const val MAX_LOCATION_AGE_MS = 120_000L
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var methodChannel: MethodChannel? = null
    private var pendingLocation: MethodChannel.Result? = null
    private var locationListener: LocationListener? = null
    private var timeout: Runnable? = null
    private var locationPermissionWasPreviouslyRequested = false

    fun attach(engine: FlutterEngine) {
        methodChannel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getCurrentLocation" -> getCurrentLocation(result)
            "cancelLocation" -> {
                finishLocation(mapOf("status" to "cancelled"))
                result.success(true)
            }
            "shareText" -> shareText(call, result)
            "openDialer" -> openDialer(call, result)
            else -> result.notImplemented()
        }
    }

    private fun hasLocationPermission(): Boolean =
        ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED

    private fun getCurrentLocation(result: MethodChannel.Result) {
        if (pendingLocation != null) {
            result.success(mapOf("status" to "busy"))
            return
        }
        if (hasLocationPermission()) {
            requestOneShotLocation(result)
            return
        }
        pendingLocation = result
        val preferences = context.getSharedPreferences(PERMISSION_PREFS, Context.MODE_PRIVATE)
        locationPermissionWasPreviouslyRequested = preferences.getBoolean(ASKED_LOCATION, false)
        preferences.edit().putBoolean(ASKED_LOCATION, true).apply()
        try {
            ActivityCompat.requestPermissions(
                activity,
                arrayOf(
                    Manifest.permission.ACCESS_COARSE_LOCATION,
                    Manifest.permission.ACCESS_FINE_LOCATION,
                ),
                LOCATION_REQUEST_CODE,
            )
        } catch (_: Exception) {
            pendingLocation = null
            result.success(mapOf("status" to "unavailable"))
        }
    }

    fun handlePermissionResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
        shouldShowRationale: Boolean,
    ) {
        if (requestCode != LOCATION_REQUEST_CODE) return
        val result = pendingLocation ?: return
        val granted = permissions.indices.any { index ->
            grantResults.getOrNull(index) == PackageManager.PERMISSION_GRANTED &&
                permissions[index] in setOf(
                    Manifest.permission.ACCESS_COARSE_LOCATION,
                    Manifest.permission.ACCESS_FINE_LOCATION,
                )
        }
        if (!granted) {
            pendingLocation = null
            result.success(
                mapOf(
                    "status" to "permission_denied",
                    "permanentlyDenied" to
                        (locationPermissionWasPreviouslyRequested && !shouldShowRationale),
                ),
            )
            return
        }
        pendingLocation = null
        requestOneShotLocation(result)
    }

    private fun requestOneShotLocation(result: MethodChannel.Result) {
        val locationManager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val hasFinePermission = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_FINE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED
        val enabledProviders = try {
            listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)
                .filter { locationManager.isProviderEnabled(it) }
        } catch (_: Exception) {
            null
        }
        if (enabledProviders == null) {
            result.success(mapOf("status" to "location_unavailable"))
            return
        }
        // Approximate-only access uses the network provider; GPS requires precise access.
        val providers = enabledProviders.filter { provider ->
            hasFinePermission || provider != LocationManager.GPS_PROVIDER
        }
        if (providers.isEmpty()) {
            result.success(
                mapOf(
                    "status" to if (enabledProviders.isEmpty()) {
                        "location_disabled"
                    } else {
                        "location_unavailable"
                    },
                ),
            )
            return
        }

        pendingLocation = result
        val listener = object : LocationListener {
            override fun onLocationChanged(location: Location) {
                val age = System.currentTimeMillis() - location.time
                if (location.time <= 0L || age !in 0L..MAX_LOCATION_AGE_MS) return
                finishLocation(
                    mapOf(
                        "status" to "success",
                        "latitude" to location.latitude,
                        "longitude" to location.longitude,
                    ),
                )
            }

            @Deprecated("Deprecated in Android")
            override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) = Unit
            override fun onProviderEnabled(provider: String) = Unit
            override fun onProviderDisabled(provider: String) = Unit
        }
        locationListener = listener
        timeout = Runnable { finishLocation(mapOf("status" to "timeout")) }
        mainHandler.postDelayed(timeout!!, LOCATION_TIMEOUT_MS)

        try {
            for (provider in providers) {
                locationManager.requestLocationUpdates(provider, 0L, 0f, listener, Looper.getMainLooper())
            }
        } catch (_: SecurityException) {
            finishLocation(mapOf("status" to "permission_denied", "permanentlyDenied" to false))
        } catch (_: Exception) {
            finishLocation(mapOf("status" to "location_unavailable"))
        }
    }

    private fun finishLocation(payload: Map<String, Any>) {
        val result = pendingLocation ?: return
        pendingLocation = null
        timeout?.let(mainHandler::removeCallbacks)
        timeout = null
        locationListener?.let { listener ->
            val manager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
            runCatching { manager.removeUpdates(listener) }
        }
        locationListener = null
        result.success(payload)
    }

    private fun shareText(call: MethodCall, result: MethodChannel.Result) {
        val text = call.argument<String>("text")?.takeIf { it.isNotBlank() }
        if (text == null) {
            result.success(mapOf("status" to "invalid_text"))
            return
        }
        val title = call.argument<String>("chooserTitle")?.takeIf { it.isNotBlank() } ?: "Share"
        try {
            val sendIntent = Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                putExtra(Intent.EXTRA_TEXT, text)
            }
            activity.startActivity(Intent.createChooser(sendIntent, title))
            result.success(mapOf("status" to "chooser_opened"))
        } catch (_: Exception) {
            result.success(mapOf("status" to "unavailable"))
        }
    }

    private fun openDialer(call: MethodCall, result: MethodChannel.Result) {
        val raw = call.argument<String>("phoneNumber").orEmpty()
        val allowedCharacters = raw.all {
            it in '0'..'9' || it == '+' || it == ' ' || it == '-' ||
                it == '(' || it == ')' || it == '.'
        }
        val normalized = raw.filter { it in '0'..'9' || it == '+' }
        val digits = normalized.count { it in '0'..'9' }
        if (!allowedCharacters || digits !in 7..15 || normalized.count { it == '+' } > 1 ||
            (normalized.contains('+') && !normalized.startsWith('+'))
        ) {
            result.success(mapOf("status" to "invalid_number"))
            return
        }
        try {
            activity.startActivity(Intent(Intent.ACTION_DIAL, Uri.fromParts("tel", normalized, null)))
            result.success(mapOf("status" to "dialer_opened"))
        } catch (_: Exception) {
            result.success(mapOf("status" to "unavailable"))
        }
    }

    fun dispose() {
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        timeout?.let(mainHandler::removeCallbacks)
        timeout = null
        locationListener?.let { listener ->
            val manager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
            runCatching { manager.removeUpdates(listener) }
        }
        locationListener = null
        pendingLocation?.let {
            pendingLocation = null
            it.success(mapOf("status" to "unavailable"))
        }
    }
}
