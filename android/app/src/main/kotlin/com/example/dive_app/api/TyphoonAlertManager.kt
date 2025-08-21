package com.example.dive_app.api

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.example.dive_app.R
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import kotlin.math.*
import org.json.JSONObject
import com.google.android.gms.wearable.Wearable
import com.google.android.gms.wearable.Node

object TyphoonAlertManager {

    private const val CHANNEL_ID = "typhoon_alert_channel"

    suspend fun checkTyphoonAlert(context: Context, lat: Double, lon: Double) {
        val arr: JSONArray? = withContext(Dispatchers.IO) { TyphoonApi.fetchRecent() }
        if (arr == null || arr.length() == 0) return

        for (i in 0 until arr.length()) {
            val typhoon = arr.getJSONObject(i)

            val tyLat = typhoon.optDouble("typLat", 0.0)
            val tyLon = typhoon.optDouble("typLon", 0.0)
            val name = typhoon.optString("typName", "태풍")

            val distance = haversine(lat, lon, tyLat, tyLon)

            if (distance < 300) {
                sendAlertToWatch(context, name, distance)  // 워치로 전송
            }

        }
    }

    private fun haversine(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
        val R = 6371.0
        val dLat = Math.toRadians(lat2 - lat1)
        val dLon = Math.toRadians(lon2 - lon1)
        val a = sin(dLat / 2).pow(2.0) +
                cos(Math.toRadians(lat1)) * cos(Math.toRadians(lat2)) *
                sin(dLon / 2).pow(2.0)
        val c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return R * c
    }

    private fun sendAlertToWatch(context: Context, typhoonName: String, distance: Double) {
        val alertJson = JSONObject().apply {
            put("typhoon", typhoonName)
            put("distance", distance)
        }.toString()

        Wearable.getNodeClient(context).connectedNodes
            .addOnSuccessListener { nodes: List<Node> ->
                nodes.forEach { node: Node ->
                    Wearable.getMessageClient(context)
                        .sendMessage(node.id, "/typhoon_alert", alertJson.toByteArray())
                }
            }
    }

    fun sendTestAlert(context: Context) {
        val json = JSONObject().apply {
            put("typhoon", "태풍 테스트 알림")
            put("distance", 123.4)
        }

        Wearable.getNodeClient(context).connectedNodes
            .addOnSuccessListener { nodes: List<Node> ->
                nodes.forEach { node: Node ->
                    Wearable.getMessageClient(context)
                        .sendMessage(node.id, "/typhoon_alert", json.toString().toByteArray())
                }
            }
    }
}
