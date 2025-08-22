package com.example.dive_app.manager

import android.content.Context
import android.util.Log
import com.google.android.gms.wearable.Wearable
import com.google.android.gms.wearable.Node
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import com.example.dive_app.api.WeatherApi

object WeatherAlertManager {

    suspend fun checkWeatherAlert(context: Context, lat: Double, lon: Double) {
        val weatherJson: JSONObject? = withContext(Dispatchers.IO) {
            WeatherApi.fetchBaseWeather(lat, lon)
        }
        if (weatherJson == null) return

        try {
            val arr = weatherJson.optJSONArray("weather") ?: return
            if (arr.length() == 0) return

            val now = arr.getJSONObject(0)   // 현재 시각 기준 데이터
            val temp = now.optString("temp", "0").toDoubleOrNull() ?: 0.0
            val wave = now.optString("pago", "0").toDoubleOrNull() ?: 0.0
            val wind = now.optString("windspd", "0").toDoubleOrNull() ?: 0.0
            val sky = now.optString("sky", "")

            val alerts = mutableListOf<String>()

            // ✅ 임계치 예시 (원하는 값으로 조정 가능)
            if (temp >= 33) alerts.add("폭염 주의 (기온 ${temp}℃)")
            if (temp <= -5) alerts.add("한파 주의 (기온 ${temp}℃)")
            if (wave >= 2.0) alerts.add("높은 파고 주의 (${wave}m)")
            if (wind >= 10.0) alerts.add("강풍 주의 (풍속 ${wind}m/s)")
            if (sky.contains("비")) alerts.add("강수 주의")

            if (alerts.isNotEmpty()) {
                val msg = alerts.joinToString("\n")
                sendAlertToWatch(context, msg)
            }

        } catch (e: Exception) {
            Log.e("WeatherAlert", "⚠️ 파싱 오류", e)
        }
    }

    private fun sendAlertToWatch(context: Context, message: String) {
        val alertJson = JSONObject().apply {
            put("title", "기상 경고")
            put("message", message)
        }.toString()

        Wearable.getNodeClient(context).connectedNodes
            .addOnSuccessListener { nodes: List<Node> ->
                nodes.forEach { node: Node ->
                    Wearable.getMessageClient(context)
                        .sendMessage(node.id, "/weather_alert", alertJson.toByteArray())
                }
            }
    }

    fun sendTestAlert(context: Context) {
        val json = JSONObject().apply {
            put("title", "기상 경고")
            put("message", "폭염 주의 (기온 34℃)\n강풍 주의 (풍속 11m/s)")
        }

        Wearable.getNodeClient(context).connectedNodes
            .addOnSuccessListener { nodes ->
                nodes.forEach { node ->
                    Wearable.getMessageClient(context)
                        .sendMessage(node.id, "/weather_alert", json.toString().toByteArray())
                }
            }
    }
}
