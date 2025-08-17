package com.example.dive_app

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable

class MainActivity: FlutterActivity() {
    private val CHANNEL = "app.dive/wear"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "sendWeather" -> {
                        sendWeatherToWatch(this, call.arguments as Map<String, Any?>)
                        result.success(null)
                    }
                    "sendTide" -> {
                        sendTideToWatch(this, call.arguments as Map<String, Any?>)
                        result.success(null)
                    }
                    "sendTemp" -> {
                        sendTempToWatch(this, call.arguments as Map<String, Any?>)
                        result.success(null)
                    }
                    "sendTempStations" -> {
                        @Suppress("UNCHECKED_CAST")
                        val arg = call.arguments as Map<String, Any?>
                        val points = (arg["points"] as? List<Map<String, Any?>>) ?: emptyList()
                        sendTempStationsToWatch(this, points)
                        result.success(null)
                    }
                    "sendFishingPoints" -> {
                        @Suppress("UNCHECKED_CAST")
                        val arg = call.arguments as Map<String, Any?>
                        val points = (arg["points"] as? List<Map<String, Any?>>) ?: emptyList()
                        sendPointsToWatch(this, points)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun sendWeatherToWatch(ctx: Context, m: Map<String, Any?>) {
        val req = PutDataMapRequest.create("/weather_info")
        val dm = req.dataMap
        fun putS(k: String) = dm.putString(k, (m[k] ?: "").toString())
        listOf("sky","windspd","temp","humidity","rain",
            "winddir","waveHt","waveDir","obs_wt").forEach { putS(it) }
        dm.putLong("ts", System.currentTimeMillis())
        Wearable.getDataClient(ctx).putDataItem(req.asPutDataRequest().setUrgent())
    }

    private fun sendTideToWatch(ctx: Context, m: Map<String, Any?>) {
        val req = PutDataMapRequest.create("/tide_info")
        val dm = req.dataMap
        fun putS(k: String) = dm.putString(k, (m[k] ?: "").toString())
        listOf("pThisDate","pName","pMul","pSun","pMoon",
            "jowi1","jowi2","jowi3","jowi4").forEach { putS(it) }
        dm.putLong("ts", System.currentTimeMillis())
        Wearable.getDataClient(ctx).putDataItem(req.asPutDataRequest().setUrgent())
    }

    private fun sendTempToWatch(ctx: Context, m: Map<String, Any?>) {
        val req = PutDataMapRequest.create("/temp_info")
        val dm = req.dataMap
        fun putS(k: String) = dm.putString(k, (m[k] ?: "").toString())
        listOf("name","temp","obs_time","distance_km").forEach { putS(it) }
        dm.putLong("ts", System.currentTimeMillis())
        Wearable.getDataClient(ctx).putDataItem(req.asPutDataRequest().setUrgent())
    }

    private fun sendTempStationsToWatch(ctx: Context, items: List<Map<String, Any?>>) {
        val req = PutDataMapRequest.create("/temp_stations")
        val dm = req.dataMap
        // 배열은 키를 0,1,2... 로 쪼개서 보냄(간단한 방식)
        items.forEachIndexed { idx, it ->
            val child = PutDataMapRequest.create("/temp_stations/$idx").dataMap
            fun putS(k: String) = child.putString(k, (it[k] ?: "").toString())
            listOf("name","temp","obs_time","distance_km").forEach { putS(it) }
            dm.putDataMap(idx.toString(), child)
        }
        dm.putInt("count", items.size)
        dm.putLong("ts", System.currentTimeMillis())
        Wearable.getDataClient(ctx).putDataItem(req.asPutDataRequest().setUrgent())
    }

    private fun sendPointsToWatch(ctx: Context, items: List<Map<String, Any?>>) {
        val req = PutDataMapRequest.create("/fishing_points")
        val dm = req.dataMap
        items.forEachIndexed { idx, it ->
            val child = PutDataMapRequest.create("/fishing_points/$idx").dataMap
            it.forEach { (k, v) -> child.putString(k, (v ?: "").toString()) }
            dm.putDataMap(idx.toString(), child)
        }
        dm.putInt("count", items.size)
        dm.putLong("ts", System.currentTimeMillis())
        Wearable.getDataClient(ctx).putDataItem(req.asPutDataRequest().setUrgent())
    }
}
