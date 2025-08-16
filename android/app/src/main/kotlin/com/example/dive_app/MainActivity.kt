package com.example.dive_app

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

import com.google.android.gms.wearable.DataClient
import com.google.android.gms.wearable.DataMap
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable

class MainActivity : FlutterActivity() {
    private val CHANNEL = "app.dive/wear"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    @Suppress("UNCHECKED_CAST")
                    val args = (call.arguments as? Map<String, Any?>) ?: emptyMap()

                    when (call.method) {
                        "sendWeather" -> {
                            sendWeatherToWatch(this, args)
                            result.success(null)
                        }
                        "sendTide" -> {
                            sendTideToWatch(this, args)
                            result.success(null)
                        }
                        "sendTemp" -> {
                            sendTempToWatch(this, args)
                            result.success(null)
                        }
                        // ✅ 추가: 낚시포인트 리스트 전송
                        "sendFishingPoints" -> {
                            sendFishingPointsToWatch(this, args)
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("WEAR_ERROR", e.message, null)
                }
            }
    }

    // ---------------------------
    // Wear OS Data Layer helpers
    // ---------------------------

    private fun dataClient(context: Context): DataClient =
        Wearable.getDataClient(context)

    private fun putMap(path: String, payload: Map<String, Any?>): PutDataMapRequest {
        val req = PutDataMapRequest.create(path)
        val map = req.dataMap

        // 공통 타임스탬프(변경 감지용)
        map.putLong("timestamp", System.currentTimeMillis())

        // 지원 타입만 안전하게 넣기
        payload.forEach { (k, v) ->
            when (v) {
                null -> { /* skip */ }
                is String  -> map.putString(k, v)
                is Int     -> map.putInt(k, v)
                is Long    -> map.putLong(k, v)
                is Double  -> map.putDouble(k, v)
                is Float   -> map.putFloat(k, v)
                is Boolean -> map.putBoolean(k, v)
                is List<*> -> {
                    val allStrings = v.all { it is String }
                    if (allStrings) {
                        @Suppress("UNCHECKED_CAST")
                        map.putStringArrayList(k, ArrayList(v as List<String>))
                    }
                }
                else -> map.putString(k, v.toString())
            }
        }
        return req
    }

    private fun sendWeatherToWatch(context: Context, args: Map<String, Any?>) {
        // 예: { "location": "Busan", "tempC": 26.4, "windKph": 12.3, "condition": "Cloudy" }
        val req = putMap("/weather", args)
        dataClient(context).putDataItem(req.asPutDataRequest().setUrgent())
    }

    private fun sendTideToWatch(context: Context, args: Map<String, Any?>) {
        // 예: { "highTime": "06:10", "lowTime": "12:42", "heightM": 1.8 }
        val req = putMap("/tide", args)
        dataClient(context).putDataItem(req.asPutDataRequest().setUrgent())
    }

    private fun sendTempToWatch(context: Context, args: Map<String, Any?>) {
        // 예: { "seaTempC": 22.1, "airTempC": 27.0 }
        val req = putMap("/temp", args)
        dataClient(context).putDataItem(req.asPutDataRequest().setUrgent())
    }

    // ----------------------------------------------------
    // ✅ 낚시포인트 리스트 -> DataMapArrayList 로 전송 (/fishing_points)
    // ----------------------------------------------------
    private fun sendFishingPointsToWatch(context: Context, args: Map<String, Any?>) {
        // Dart 쪽에서 {"points": [ { .. }, { .. } ]} 형태로 보냄
        @Suppress("UNCHECKED_CAST")
        val points = (args["points"] as? List<Map<String, Any?>>) ?: emptyList()

        val req = PutDataMapRequest.create("/fishing_points")
        val map = req.dataMap

        // 변경 감지용 타임스탬프
        map.putLong("timestamp", System.currentTimeMillis())

        // 리스트 변환
        val dmaps = ArrayList<DataMap>(points.size)
        for (p in points) {
            val dm = DataMap()

            // 문자열 필드
            dm.putString("name",      (p["name"] ?: "").toString())
            dm.putString("point_nm",  (p["point_nm"] ?: p["name"] ?: "").toString())
            dm.putString("addr",      (p["addr"] ?: "").toString())
            dm.putString("dpwt",      (p["dpwt"] ?: "").toString())
            dm.putString("material",  (p["material"] ?: "").toString())
            dm.putString("tide_time", (p["tide_time"] ?: "").toString())
            dm.putString("target",    (p["target"] ?: "").toString())
            dm.putString("point_dt",  (p["point_dt"] ?: "").toString())
            dm.putString("photo",     (p["photo"] ?: "").toString())

            // 좌표/거리 숫자 필드
            dm.putDouble("lat", (p["lat"] as? Number)?.toDouble() ?: 0.0)
            dm.putDouble("lon", (p["lon"] as? Number)?.toDouble() ?: 0.0)
            dm.putDouble("distance_km", (p["distance_km"] as? Number)?.toDouble()
                ?: (p["distance_km"]?.toString()?.toDoubleOrNull() ?: 0.0)
            )

            dmaps.add(dm)
        }

        map.putDataMapArrayList("points", dmaps)

        dataClient(context).putDataItem(req.asPutDataRequest().setUrgent())
    }
}
