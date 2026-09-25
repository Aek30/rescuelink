package com.rmutt.rescuelink

import android.content.Context
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.location.GnssStatus
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import io.flutter.plugin.common.MethodChannel
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailabilityLight
import com.google.android.gms.location.CurrentLocationRequest
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.CancellationTokenSource

/** Android providers remain available even when optional Google fused location is unavailable. */
class LocationCapture(context: Context) : LocationListener {
    private val appContext = context.applicationContext
    private val manager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
    private val handler = Handler(Looper.getMainLooper())
    private var pending: MethodChannel.Result? = null
    private var satellites: Int? = null
    private var usedSatellites: Int? = null
    private var fixesReceived = 0
    private var providersUsed = emptyList<String>()
    private var providerErrors = 0
    private var fusedCancellation: CancellationTokenSource? = null
    private val gnss = object : GnssStatus.Callback() {
        override fun onSatelliteStatusChanged(status: GnssStatus) {
            satellites = status.satelliteCount
            usedSatellites = (0 until status.satelliteCount).count { status.usedInFix(it) }
        }
    }
    private val timeout = Runnable { finishError("timeout", "No fresh fix within 60 seconds") }

    fun capture(result: MethodChannel.Result) {
        if (pending != null) { result.error("busy", "Location request already running", null); return }
        pending = result
        satellites = null
        usedSatellites = null
        fixesReceived = 0
        providerErrors = 0
        providersUsed = emptyList()
        try {
            val providers = listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)
                .filter { manager.allProviders.contains(it) && manager.isProviderEnabled(it) }
            if (providers.isEmpty()) { finishError("disabled", "Enable location providers"); return }
            providersUsed = providers
            // Only accept a genuinely recent system fix, preserving its timestamp.
            for (provider in providers) {
                try {
                    manager.getLastKnownLocation(provider)?.let { onLocationChanged(it) }
                    if (pending == null) return
                } catch (_: Exception) { providerErrors++ }
            }
            if (providers.contains(LocationManager.GPS_PROVIDER)) {
                try { manager.registerGnssStatusCallback(gnss, handler) } catch (_: Exception) { }
            }
            var registered = startFused(result)
            var permissionDenied = false
            for (provider in providers) {
                try {
                    manager.requestLocationUpdates(provider, 0L, 0f, this, Looper.getMainLooper())
                    registered = true
                } catch (_: SecurityException) { permissionDenied = true; providerErrors++ }
                catch (_: Exception) { providerErrors++ }
            }
            if (!registered) { finishError(if (permissionDenied) "permission" else "provider", "No available location provider"); return }
            handler.postDelayed(timeout, 60000L)
        } catch (_: SecurityException) { finishError("permission", "Location permission required") }
        catch (e: Exception) { finishError("provider", e.message ?: "Location unavailable") }
    }

    private fun startFused(expected: MethodChannel.Result): Boolean {
        try {
            if (GoogleApiAvailabilityLight.getInstance().isGooglePlayServicesAvailable(appContext) != ConnectionResult.SUCCESS) return false
            val cancellation = CancellationTokenSource()
            fusedCancellation = cancellation
            val request = CurrentLocationRequest.Builder()
                .setPriority(Priority.PRIORITY_HIGH_ACCURACY)
                .setMaxUpdateAgeMillis(15000L)
                .setDurationMillis(60000L)
                .build()
            LocationServices.getFusedLocationProviderClient(appContext)
                .getCurrentLocation(request, cancellation.token)
                .addOnSuccessListener { fix -> if (pending === expected && fix != null) onLocationChanged(fix) }
                .addOnFailureListener { if (pending === expected) providerErrors++ }
            return true
        } catch (_: Exception) { providerErrors++; return false }
    }

    override fun onLocationChanged(location: Location) {
        if (pending == null) return
        fixesReceived++
        // Some providers omit elapsedRealtimeNanos; validate their real timestamp instead.
        val ageMillis = if (location.elapsedRealtimeNanos > 0) (SystemClock.elapsedRealtimeNanos() - location.elapsedRealtimeNanos) / 1000000L else System.currentTimeMillis() - location.time
        if (ageMillis < 0 || ageMillis > 15000L || !location.hasAccuracy() || !location.accuracy.isFinite() || location.accuracy < 0 || location.time <= 0 ||
            !location.latitude.isFinite() || !location.longitude.isFinite() || location.latitude !in -90.0..90.0 || location.longitude !in -180.0..180.0) return
        val format = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply { timeZone = TimeZone.getTimeZone("UTC") }
        val result = pending
        cleanup()
        result?.success(mapOf("latitude" to location.latitude, "longitude" to location.longitude,
            "accuracy" to location.accuracy.toDouble(), "capturedAt" to format.format(Date(location.time))))
    }
    override fun onProviderDisabled(provider: String) {
        if (pending != null && manager.getProviders(true).none { it == LocationManager.GPS_PROVIDER || it == LocationManager.NETWORK_PROVIDER }) finishError("disabled", "Location disabled")
    }
    override fun onProviderEnabled(provider: String) {}
    @Deprecated("Legacy callback")
    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
    fun cancel() { if (pending != null) finishError("canceled", "Location request canceled") }
    private fun finishError(code: String, message: String) {
        val result = pending
        val details = mapOf("providers" to providersUsed, "satellites" to satellites, "usedSatellites" to usedSatellites, "fixesReceived" to fixesReceived, "providerErrors" to providerErrors)
        cleanup()
        result?.error(code, message, details)
    }
    private fun cleanup() {
        pending = null
        fusedCancellation?.cancel()
        fusedCancellation = null
        handler.removeCallbacks(timeout)
        try { manager.removeUpdates(this) } catch (_: Exception) {}
        try { manager.unregisterGnssStatusCallback(gnss) } catch (_: Exception) {}
    }
}
