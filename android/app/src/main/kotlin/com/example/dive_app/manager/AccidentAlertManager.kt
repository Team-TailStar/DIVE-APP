package com.example.dive_app.manager

import android.content.Context
import android.location.Geocoder
import android.util.Log
import com.example.dive_app.CoastalAccidentRepo
import com.example.dive_app.util.getCurrentLocation
import com.google.android.gms.wearable.Node
import com.google.android.gms.wearable.Wearable
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*
import kotlin.math.max

object AccidentAlertManager {
    private const val PREFS = "accident_alert_prefs"
    private const val KEY_LAST_AT = "last_at"
    private const val KEY_LAST_REGION = "last_region"
    private const val KEY_LAST_TYPE = "last_type"

    /** 사고 데이터 확인 후 조건 만족 시 알림 전송 */
    suspend fun checkAndNotify(
        context: Context,
        lat: Double? = null,
        lon: Double? = null,
        threshold: Int = 10,
        cooldownMinutes: Int = 120
    ) {
        try {
            CoastalAccidentRepo.ensureLoaded(context)

            // 현재 위치 확인 (없으면 서울 시청 좌표 fallback)
            val coords = lat?.let { it to requireNotNull(lon) } ?: getCurrentLocation(context)
            val (useLat, useLon) = coords ?: (37.5665 to 126.9780)

            // 위치 기반 지역명 추출
            val (regionKey, displayRegion) = regionFromLocation(context, useLat, useLon)
            if (regionKey.isBlank()) {
                Log.w("AccidentAlertManager", "⚠️ empty region (lat=$useLat, lon=$useLon)")
                return
            }

            // 지역별 사고 통계 조회
            val json = CoastalAccidentRepo.queryByRegion(regionKey, null)
            val byType = json.optJSONObject("summary")?.optJSONArray("by_type") ?: JSONArray()
            if (byType.length() == 0) {
                Log.d("AccidentAlertManager", "no rows for $regionKey ($displayRegion)")
                return
            }

            // 최다 사고 장소 유형 선택
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

            Log.d("AccidentAlertManager", "region=$displayRegion topType=$topType topAcc=$topAcc")

            // 임계값 미만이면 무시
            if (topAcc < threshold) {
                Log.d("AccidentAlertManager", "below threshold $topAcc < $threshold @ $displayRegion")
                return
            }

            // 쿨다운 확인
            if (!checkCooldown(context, displayRegion, topType, cooldownMinutes)) {
                Log.d("AccidentAlertManager", "cooldown active for $displayRegion / $topType")
                return
            }

            // 최종 알림 전송
            val title = "연안사고 위험 알림"
            val message = "${displayRegion} · ${topType} (사고 ${topAcc}건)\n안전에 주의하세요."

            val payload = JSONObject().apply {
                put("title", title)
                put("message", message)
            }
            sendToWatch(context, payload)

        } catch (e: Exception) {
            Log.e("AccidentAlertManager", "❌ checkAndNotify failed", e)
        }
    }

    /** 수동 테스트 알림 */
    fun sendTestAlert(context: Context) {
        val json = JSONObject().apply {
            put("title", "연안사고 위험 알림")
            put("message", "부산 해운대구 · 갯바위 (사고 12건)\n안전에 주의하세요.")
        }
        sendToWatch(context, json)
    }

    // -------- helpers --------

    /** 워치로 알림 전송 */
    private fun sendToWatch(context: Context, payload: JSONObject) {
        Wearable.getNodeClient(context).connectedNodes
            .addOnSuccessListener { nodes: List<Node> ->
                if (nodes.isEmpty()) {
                    Log.w("AccidentAlertManager", "⚠️ no connected watch; payload=$payload")
                }
                nodes.forEach { node ->
                    Wearable.getMessageClient(context)
                        .sendMessage(node.id, "/accident_alert", payload.toString().toByteArray())
                        .addOnSuccessListener {
                            Log.d("AccidentAlertManager", "✅ SENT to ${node.displayName} (${node.id}) → $payload")
                        }
                        .addOnFailureListener { e ->
                            Log.e("AccidentAlertManager", "❌ send FAILED to ${node.id}", e)
                        }
                }
            }
            .addOnFailureListener { e ->
                Log.e("AccidentAlertManager", "❌ failed to get connected nodes", e)
            }
    }

    /** 위도·경도 → 행정구역 문자열 */
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
            Log.w("AccidentAlertManager", "⚠️ geocoder fail", e)
            "" to ""
        }
    }

    /** 알림 중복 방지 (쿨다운) */
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
