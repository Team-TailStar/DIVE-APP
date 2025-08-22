package com.example.dive_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.location.Geocoder
import android.util.Log
import com.example.dive_app.util.getCurrentLocation
import com.google.android.gms.wearable.Wearable
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import org.json.JSONObject
import java.util.Locale

class AccidentTestReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val threshold = intent.getIntExtra("threshold", 10)
        val regionOverride = intent.getStringExtra("region")  // e.g. "부산"
        val dryRun = intent.getBooleanExtra("dryRun", false)

        val pending = goAsync()
        CoroutineScope(Dispatchers.IO).launch {
            try {
                CoastalAccidentRepo.ensureLoaded(context)

                // 1) region override가 있으면 사용, 없으면 현재 위치로 행정명 생성
                val regionPair = if (!regionOverride.isNullOrBlank()) {
                    regionOverride to regionOverride
                } else {
                    val coords = getCurrentLocation(context) ?: (37.5665 to 126.9780) // 서울 기본값
                    regionFromLocation(context, coords.first, coords.second)
                }
                val regionKey = regionPair.first
                val displayRegion = regionPair.second
                if (regionKey.isBlank()) {
                    Log.w("AccidentAlert", "empty region"); pending.finish(); return@launch
                }

                // 2) CSV 조회 후 종류별 합계에서 최다 사고 장소종류 선택
                val json = CoastalAccidentRepo.queryByRegion(regionKey, null)
                val byType = json.optJSONObject("summary")?.optJSONArray("by_type")
                var topType = ""; var topAcc = 0
                if (byType != null) {
                    for (i in 0 until byType.length()) {
                        val o = byType.getJSONObject(i)
                        val acc = o.optInt("accidents", 0)
                        if (acc > topAcc) { topAcc = acc; topType = o.optString("place_se_nm") }
                    }
                }
                if (topAcc < threshold) {
                    Log.d("AccidentAlert","below threshold $topAcc<$threshold in $displayRegion")
                    pending.finish(); return@launch
                }

                val message = "⚠️ ${eunneun(topType)} 위험한 지역입니다"
                val payload = JSONObject().apply {
                    put("type", "accident")
                    put("region", displayRegion)
                    put("place_se", topType)
                    put("accidents", topAcc)
                    put("message", message)
                }.toString()

                if (dryRun) {
                    Log.d("AccidentAlert", "DRYRUN would send: $payload")
                } else {
                    val nodes = Wearable.getNodeClient(context).connectedNodes.await()
                    if (nodes.isEmpty()) {
                        Log.w("AccidentAlert","no connected watch; payload=$payload")
                    } else {
                        for (n in nodes) {
                            Wearable.getMessageClient(context)
                                .sendMessage(n.id, "/alert_accident", payload.toByteArray())
                                .await()
                        }
                        Log.d("AccidentAlert","sent watch accident alert: $payload")
                    }
                }
            } catch (e: Exception) {
                Log.e("AccidentAlert","Receiver fail", e)
            } finally { pending.finish() }
        }
    }

    private fun regionFromLocation(context: Context, lat: Double, lon: Double): Pair<String,String> {
        return try {
            val g = Geocoder(context, Locale.KOREA)
            val list = g.getFromLocation(lat, lon, 1)
            if (list.isNullOrEmpty()) "" to "" else {
                val a = list[0]
                val key = listOfNotNull(a.adminArea, a.locality, a.subLocality).joinToString(" ").trim()
                key to key
            }
        } catch (e: Exception) { Log.w("AccidentAlert","geocoder fail", e); "" to "" }
    }
    private fun hasJong(ch: Char): Boolean {
        val code = ch.code - 0xAC00
        return code in 0 until 11172 && (code % 28) != 0
    }
    private fun eunneun(noun: String): String {
        val c = noun.lastOrNull() ?: return "는"
        return noun + if (hasJong(c)) "은" else "는"
    }
}
