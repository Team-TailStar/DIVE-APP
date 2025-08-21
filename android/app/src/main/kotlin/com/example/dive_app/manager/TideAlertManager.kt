package com.example.dive_app.manager

import android.content.Context
import android.util.Log
import com.google.android.gms.wearable.Node
import com.google.android.gms.wearable.Wearable
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*
import com.example.dive_app.api.TideApi

object TideAlertManager {

    suspend fun checkTideAlert(context: Context, lat: Double, lon: Double) {
        val tideArr: JSONArray? = withContext(Dispatchers.IO) { TideApi.fetchTide(lat, lon) }
        if (tideArr == null || tideArr.length() == 0) return

        try {
            val todayData = tideArr.getJSONObject(0)   // 📌 첫 번째가 오늘 데이터
            val pTimeKeys = listOf("pTime1", "pTime2", "pTime3", "pTime4")

            // 현재 시간
            val now = Calendar.getInstance()
            val sdf = SimpleDateFormat("HH:mm", Locale.KOREA)

            for (key in pTimeKeys) {
                val raw = todayData.optString(key, "")
                if (raw.isEmpty()) continue

                // 예: "07:06 (81) ▲+54" → 시간만 파싱
                val timePart = raw.split(" ")[0]  // "07:06"

                val parsed = sdf.parse(timePart) ?: continue

                val tideTime = Calendar.getInstance().apply {
                    time = parsed
                    set(Calendar.YEAR, now.get(Calendar.YEAR))
                    set(Calendar.MONTH, now.get(Calendar.MONTH))
                    set(Calendar.DAY_OF_MONTH, now.get(Calendar.DAY_OF_MONTH))
                }

                val diffMin = (tideTime.timeInMillis - now.timeInMillis) / (1000 * 60)

                // 📌 만조(▲)만 체크 + 1시간 이내
                if (raw.contains("▲") && diffMin in 0..60) {
                    sendAlertToWatch(context, raw)
                }
            }

        } catch (e: Exception) {
            Log.e("TideAlert", "⚠️ 파싱 오류", e)
        }
    }

    private fun sendAlertToWatch(context: Context, message: String) {
        val alertJson = JSONObject().apply {
            put("tide_alert", "만조 임박: $message")
        }.toString()

        Wearable.getNodeClient(context).connectedNodes
            .addOnSuccessListener { nodes: List<Node> ->
                nodes.forEach { node ->
                    Wearable.getMessageClient(context)
                        .sendMessage(node.id, "/tide_alert", alertJson.toByteArray())
                }
            }
    }

    fun sendTestAlert(context: Context) {
        val json = JSONObject().apply {
            put("tide_alert", "테스트 물때 알림 - 만조 임박")
        }

        Wearable.getNodeClient(context).connectedNodes
            .addOnSuccessListener { nodes ->
                nodes.forEach { node ->
                    Wearable.getMessageClient(context)
                        .sendMessage(node.id, "/tide_alert", json.toString().toByteArray())
                }
            }
    }
}
