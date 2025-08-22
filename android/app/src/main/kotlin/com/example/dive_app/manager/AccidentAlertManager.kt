package com.example.dive_app.manager

import android.content.Context
import android.location.Geocoder
import android.util.Log
import com.example.dive_app.CoastalAccidentRepo
import com.example.dive_app.util.getCurrentLocation
import com.google.android.gms.wearable.Wearable
import kotlinx.coroutines.tasks.await
import org.json.JSONArray
import org.json.JSONObject
import java.util.Locale
import kotlin.math.max

object AccidentAlertManager {
    private const val TAG = "AccidentAlertManager"
    private const val WATCH_PATH = "/alert_accident"

    // simple spam control
    private const val PREFS = "accident_alert_prefs"
    private const val KEY_LAST_AT = "last_at"
    private const val KEY_LAST_REGION = "last_region"
    private const val KEY_LAST_TYPE = "last_type"

    suspend fun checkAndNotify(
        context: Context,
        lat: Double? = null,
        lon: Double? = null,
        threshold: Int = 10,
        cooldownMinutes: Int = 120,
        dryRun: Boolean = false
    ): JSONObject? {
        CoastalAccidentRepo.ensureLoaded(context)

        val coords = lat?.let { it to requireNotNull(lon) } ?: getCurrentLocation(context)
        val (useLat, useLon) = coords ?: (37.5665 to 126.9780)
        val (regionKey, displayRegion) = regionFromLocation(context, useLat, useLon)
        if (regionKey.isBlank()) {
            Log.w(TAG, "empty region"); return null
        }

        val json = CoastalAccidentRepo.queryByRegion(regionKey, null)
        val byType = json.optJSONObject("summary")?.optJSONArray("by_type") ?: JSONArray()
        if (byType.length() == 0) {
            Log.d(TAG, "no rows for $regionKey"); return null
        }

        var topType = ""; var topAcc = 0
        for (i in 0 until byType.length()) {
            val o = byType.getJSONObject(i)
            val acc = o.optInt("accidents", 0)
            if (acc > topAcc) { topAcc = acc; topType = o.optString("place_se_nm") }
        }
        if (topAcc < threshold) {
            Log.d(TAG, "below threshold $topAcc < $threshold @ $displayRegion"); return null
        }

        if (!checkCooldown(context, displayRegion, topType, cooldownMinutes)) {
            Log.d(TAG, "cooldown active for $displayRegion / $topType"); return null
        }

        val message = "⚠️ ${eunneun(topType)} 위험한 지역입니다"
        val payload = JSONObject().apply {
            put("type", "accident")
            put("region", displayRegion)
            put("place_se", topType)
            put("accidents", topAcc)
            put("message", message)
        }

        //if (dryRun) {
            //Log.d(TAG, "DRYRUN would send: $payload")
            //return payload
       // }

        if (dryRun) {
            Log.d("AccidentAlertManager", "AccidentAlertTest: DRYRUN would send: $payload")
            return payload
        }

        val nodes = Wearable.getNodeClient(context).connectedNodes.await()
        if (nodes.isEmpty()) {
            Log.w(TAG, "no connected watch; payload=$payload")
        } else {
            for (n in nodes) {
                Wearable.getMessageClient(context)
                    .sendMessage(n.id, WATCH_PATH, payload.toString().toByteArray())
                    .await()
            }
            //.d(TAG, "sent watch accident alert: $payload")
            Log.d("AccidentAlertManager", "AccidentAlertTest: SENT $payload")
        }
        return payload
    }

    // -------- helpers --------

    private fun regionFromLocation(context: Context, lat: Double, lon: Double): Pair<String, String> {
        return try {
            val g = Geocoder(context, Locale.KOREA)
            val list = g.getFromLocation(lat, lon, 1)
            if (list.isNullOrEmpty()) "" to "" else {
                val a = list[0]
                val key = listOfNotNull(a.adminArea, a.locality, a.subLocality)
                    .joinToString(" ")
                    .trim()
                key to key
            }
        } catch (e: Exception) {
            Log.w(TAG, "geocoder fail", e); "" to ""
        }
    }

    private fun hasJong(ch: Char): Boolean {
        val code = ch.code - 0xAC00
        return code in 0 until 11172 && (code % 28) != 0
    }
    private fun eunneun(noun: String): String {
        val c = noun.lastOrNull() ?: return "는"
        return noun + if (hasJong(c)) "은" else "는"
    }

    private fun checkCooldown(
        context: Context,
        region: String,
        type: String,
        cooldownMinutes: Int
    ): Boolean {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val lastAt = prefs.getLong(KEY_LAST_AT, 0L)
        val lastRegion = prefs.getString(KEY_LAST_REGION, null)
        val lastType = prefs.getString(KEY_LAST_TYPE, null)
        val now = System.currentTimeMillis()
        val coolMs = max(0, cooldownMinutes) * 60_000L

        val same = (region == lastRegion && type == lastType)
        if (same && now - lastAt < coolMs) return false

        prefs.edit()
            .putLong(KEY_LAST_AT, now)
            .putString(KEY_LAST_REGION, region)
            .putString(KEY_LAST_TYPE, type)
            .apply()
        return true
    }
}
