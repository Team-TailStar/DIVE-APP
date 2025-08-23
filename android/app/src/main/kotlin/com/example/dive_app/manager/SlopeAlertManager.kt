package com.example.dive_app.manager

import android.content.Context
import android.location.Geocoder
import android.util.Log
import com.example.dive_app.CoastalSlopeRepo
import com.example.dive_app.util.getCurrentLocation
import com.google.android.gms.wearable.Node
import com.google.android.gms.wearable.Wearable
import org.json.JSONArray
import org.json.JSONObject
import java.util.*
import kotlin.math.max

object SlopeAlertManager {
    private const val PREFS = "slope_alert_prefs"
    private const val KEY_LAST_AT = "last_at"
    private const val KEY_LAST_REGION = "last_region"
    private const val KEY_LAST_SPOT = "last_spot"

    /**
     * 경사도 위험 알림 체크
     * @param threshold 기본 임계 경사값 (예: 30° 이상 위험)
     * @param cooldownMinutes 같은 장소 중복 알림 제한 시간 (분)
     */
    suspend fun checkAndNotify(
        context: Context,
        lat: Double? = null,
        lon: Double? = null,
        threshold: Double = 30.0,
        cooldownMinutes: Int = 120
    ) {
        try {
            CoastalSlopeRepo.ensureLoaded(context)

            // 현재 위치 (기본값: 서울시청)
            val coords = lat?.let { it to requireNotNull(lon) } ?: getCurrentLocation(context)
            val (useLat, useLon) = coords ?: (37.5665 to 126.9780)

            // 위치 → 행정구역 문자열
            val (regionKey, displayRegion) = regionFromLocation(context, useLat, useLon)
            if (regionKey.isBlank()) {
                Log.w("SlopeAlertManager", "⚠️ empty region (lat=$useLat, lon=$useLon)")
                return
            }

            // 지역 급경사지 조회
            val jsonArr: JSONArray = CoastalSlopeRepo.queryByRegion(regionKey)
            if (jsonArr.length() == 0) {
                Log.d("SlopeAlertManager", "no slope rows for $regionKey ($displayRegion)")
                return
            }

            // 가장 위험한 지점 찾기 (경사도 최댓값)
            var topSpot = ""
            var topGradient = 0.0
            for (i in 0 until jsonArr.length()) {
                val o = jsonArr.getJSONObject(i)
                val gradient = o.optDouble("gradient", 0.0)
                if (gradient > topGradient) {
                    topGradient = gradient
                    topSpot = o.optString("sta_nm")
                }
            }

            Log.d("SlopeAlertManager", "region=$displayRegion topSpot=$topSpot gradient=$topGradient")

            // 임계값 미만이면 무시
            if (topGradient < threshold) {
                Log.d("SlopeAlertManager", "below threshold $topGradient < $threshold @ $displayRegion")
                return
            }

            // 쿨다운 확인
            if (!checkCooldown(context, displayRegion, topSpot, cooldownMinutes)) {
                Log.d("SlopeAlertManager", "cooldown active for $displayRegion / $topSpot")
                return
            }

            // 알림 메시지 구성
            val title = "급경사지 위험 알림"
            val message = "${displayRegion} · ${topSpot} (경사도 ${String.format("%.1f", topGradient)}°)\n안전에 주의하세요."

            val payload = JSONObject().apply {
                put("title", title)
                put("message", message)
            }
            sendToWatch(context, payload)

        } catch (e: Exception) {
            Log.e("SlopeAlertManager", "❌ checkAndNotify failed", e)
        }
    }

    /** 수동 테스트 알림 */
    fun sendTestAlert(context: Context) {
        val json = JSONObject().apply {
            put("title", "급경사지 위험 알림")
            put("message", "삼척시 · 갈남해수욕장 (경사도 45.0°)\n안전에 주의하세요.")
        }
        sendToWatch(context, json)
    }

    // -------- helpers --------

    private fun sendToWatch(context: Context, payload: JSONObject) {
        Wearable.getNodeClient(context).connectedNodes
            .addOnSuccessListener { nodes: List<Node> ->
                if (nodes.isEmpty()) {
                    Log.w("SlopeAlertManager", "⚠️ no connected watch; payload=$payload")
                }
                nodes.forEach { node ->
                    Wearable.getMessageClient(context)
                        .sendMessage(node.id, "/slope_alert", payload.toString().toByteArray())
                        .addOnSuccessListener {
                            Log.d("SlopeAlertManager", "✅ SENT to ${node.displayName} (${node.id}) → $payload")
                        }
                        .addOnFailureListener { e ->
                            Log.e("SlopeAlertManager", "❌ send FAILED to ${node.id}", e)
                        }
                }
            }
            .addOnFailureListener { e ->
                Log.e("SlopeAlertManager", "❌ failed to get connected nodes", e)
            }
    }

    /** 위경도 → 행정구역 문자열 */
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
            Log.w("SlopeAlertManager", "⚠️ geocoder fail", e)
            "" to ""
        }
    }

    /** 알림 중복 방지 (쿨다운) */
    private fun checkCooldown(
        context: Context,
        region: String,
        spot: String,
        cooldownMinutes: Int
    ): Boolean {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val lastAt = prefs.getLong(KEY_LAST_AT, 0L)
        val lastRegion = prefs.getString(KEY_LAST_REGION, null)
        val lastSpot = prefs.getString(KEY_LAST_SPOT, null)
        val now = System.currentTimeMillis()
        val coolMs = max(0, cooldownMinutes) * 60_000L

        val same = (region == lastRegion && spot == lastSpot)
        if (same && now - lastAt < coolMs) return false

        prefs.edit()
            .putLong(KEY_LAST_AT, now)
            .putString(KEY_LAST_REGION, region)
            .putString(KEY_LAST_SPOT, spot)
            .apply()
        return true
    }
}
