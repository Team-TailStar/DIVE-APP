package com.example.dive_app.manager

import android.content.Context
import android.location.Geocoder
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.example.dive_app.CoastalAccidentRepo
import com.example.dive_app.util.getCurrentLocation
import com.google.android.gms.wearable.Wearable
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.Date
import kotlin.math.max

/**
 * Accident alerts to Wear OS — refactored in the same style as your tide alert manager.
 * - Adds sendTestAlert()
 * - Adds strong logging ("AccidentAlertTest: …")
 * - Extracts sendToWatch() helper
 * - Geocoder work moved onto Dispatchers.IO
 * - Optional WorkManager worker (AccidentWorker) logs when started
 */
object AccidentAlertManager {
    private const val TAG = "AccidentAlertManager"
    private const val WATCH_PATH = "/alert_accident"

    // simple spam control
    private const val PREFS = "accident_alert_prefs"
    private const val KEY_LAST_AT = "last_at"
    private const val KEY_LAST_REGION = "last_region"
    private const val KEY_LAST_TYPE = "last_type"

    /**
     * Query accident stats for the current (or provided) location and notify the watch
     * if the top accident type in the region exceeds [threshold].
     */
    suspend fun checkAndNotify(
        context: Context,
        lat: Double? = null,
        lon: Double? = null,
        threshold: Int = 10,
        cooldownMinutes: Int = 120,
        dryRun: Boolean = false
    ): JSONObject? = withContext(Dispatchers.IO) {
        Log.d(TAG, "AccidentAlertTest: checkAndNotify threshold=$threshold cooldown=$cooldownMinutes dryRun=$dryRun")

        CoastalAccidentRepo.ensureLoaded(context)

        val coords = lat?.let { it to requireNotNull(lon) } ?: getCurrentLocation(context)
        val (useLat, useLon) = coords ?: (37.5665 to 126.9780)

        val (regionKey, displayRegion) = regionFromLocationIO(context, useLat, useLon)
        if (regionKey.isBlank()) {
            Log.w(TAG, "AccidentAlertTest: empty region (lat=$useLat, lon=$useLon)")
            return@withContext null
        }

        val json = CoastalAccidentRepo.queryByRegion(regionKey, null)
        val byType = json.optJSONObject("summary")?.optJSONArray("by_type") ?: JSONArray()
        if (byType.length() == 0) {
            Log.d(TAG, "AccidentAlertTest: no rows for $regionKey ($displayRegion)")
            return@withContext null
        }

        var topType = ""
        var topAcc = 0
        for (i in 0 until byType.length()) {
            val o = byType.getJSONObject(i)
            val acc = o.optInt("accidents", 0)
            if (acc > topAcc) {
                topAcc = acc
                topType = o.optString("place_se_nm")
            }
        }

        Log.d(TAG, "AccidentAlertTest: region=$displayRegion topType=$topType topAcc=$topAcc")

        if (topAcc < threshold) {
            Log.d(TAG, "AccidentAlertTest: below threshold $topAcc < $threshold @ $displayRegion")
            return@withContext null
        }

        if (!checkCooldown(context, displayRegion, topType, cooldownMinutes)) {
            Log.d(TAG, "AccidentAlertTest: cooldown active for $displayRegion / $topType")
            return@withContext null
        }

        val message = "⚠️ ${eunneun(topType)} 위험한 지역입니다"
        val payload = basePayload(
            type = "accident",
            region = displayRegion,
            placeType = topType,
            accidents = topAcc,
            message = message
        )

        sendToWatch(context, payload, dryRun)
        return@withContext payload
    }

    /**
     * Manual test alert. Uses a simple payload and can run in DRYRUN mode.
     */
    suspend fun sendTestAlert(
        context: Context,
        region: String? = null,
        placeType: String? = null,
        accidents: Int = 12,
        dryRun: Boolean = true
    ): JSONObject = withContext(Dispatchers.IO) {
        val displayRegion = region ?: "테스트 지역"
        val t = placeType ?: "갯바위"
        val payload = basePayload(
            type = "accident_test",
            region = displayRegion,
            placeType = t,
            accidents = accidents,
            message = "테스트 사고 알림 - ${eunneun(t)} 위험 주의"
        )
        sendToWatch(context, payload, dryRun)
        payload
    }

    // -------- helpers --------

    private suspend fun sendToWatch(context: Context, payload: JSONObject, dryRun: Boolean) {
        if (dryRun) {
            Log.d(TAG, "AccidentAlertTest: DRYRUN would send: $payload")
            return
        }

        val nodes = try {
            Wearable.getNodeClient(context).connectedNodes.await()
        } catch (e: Exception) {
            Log.e(TAG, "AccidentAlertTest: failed to get connected nodes", e)
            emptyList()
        }

        if (nodes.isEmpty()) {
            Log.w(TAG, "AccidentAlertTest: no connected watch; payload=$payload")
            return
        }

        for (n in nodes) {
            try {
                Wearable.getMessageClient(context)
                    .sendMessage(n.id, WATCH_PATH, payload.toString().toByteArray())
                    .await()
                Log.d(TAG, "AccidentAlertTest: SENT to ${n.displayName} (${n.id}) → $payload")
            } catch (e: Exception) {
                Log.e(TAG, "AccidentAlertTest: send FAILED to ${n.id}", e)
            }
        }
    }

    private fun basePayload(
        type: String,
        region: String,
        placeType: String,
        accidents: Int,
        message: String
    ): JSONObject {
        val ts = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.KOREA).format(Date())
        return JSONObject().apply {
            put("type", type)
            put("region", region)
            put("place_se", placeType)
            put("accidents", accidents)
            put("message", message)
            put("timestamp", ts)
        }
    }

    private suspend fun regionFromLocationIO(context: Context, lat: Double, lon: Double): Pair<String, String> =
        withContext(Dispatchers.IO) {
            try {
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
                Log.w(TAG, "AccidentAlertTest: geocoder fail", e)
                "" to ""
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

/**
 * Optional: background worker that can trigger the same alert flow.
 * Input keys (Data):
 *  - "threshold" (Int)
 *  - "cooldownMinutes" (Int)
 *  - "dryRun" (Boolean)
 */
class AccidentWorker(
    private val ctx: Context,
    params: WorkerParameters
) : CoroutineWorker(ctx, params) {

    companion object {
        private const val TAG = "AccidentWorker"
    }

    override suspend fun doWork(): Result {
        Log.d(TAG, "AccidentAlertTest: worker started")

        return try {
            val threshold = inputData.getInt("threshold", 10)
            val cooldown = inputData.getInt("cooldownMinutes", 120)
            val dryRun = inputData.getBoolean("dryRun", true)

            // If you want to pass a lat/lon, add them to inputData and read here.
            val payload = AccidentAlertManager.checkAndNotify(
                context = ctx,
                lat = null,
                lon = null,
                threshold = threshold,
                cooldownMinutes = cooldown,
                dryRun = dryRun
            )

            Log.d(TAG, "AccidentAlertTest: worker finished payload=$payload")
            Result.success()
        } catch (t: Throwable) {
            Log.e(TAG, "AccidentAlertTest: worker failed", t)
            Result.retry()
        }
    }
}
