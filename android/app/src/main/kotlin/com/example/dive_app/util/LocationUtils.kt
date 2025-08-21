// com/example/dive_app/util/LocationUtils.kt
package com.example.dive_app.util

import android.content.Context
import android.annotation.SuppressLint
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume

@SuppressLint("MissingPermission")
suspend fun getCurrentLocation(context: Context): Pair<Double, Double>? {
    val fused = LocationServices.getFusedLocationProviderClient(context)
    return suspendCancellableCoroutine { cont ->
        fused.getCurrentLocation(Priority.PRIORITY_BALANCED_POWER_ACCURACY, null)
            .addOnSuccessListener { loc ->
                if (loc != null) cont.resume(Pair(loc.latitude, loc.longitude), null)
                else cont.resume(null, null)
            }
            .addOnFailureListener { cont.resume(null, null) }
    }
}
