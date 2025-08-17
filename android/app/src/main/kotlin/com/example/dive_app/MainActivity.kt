package com.example.dive_app

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

    private fun dataClient(context: Context): DataClient =
        Wearable.getDataClient(context)

    private fun putMap(path: String, payload: Map<String, Any?>): PutDataMapRequest {
        val req = PutDataMapRequest.create(path)
        val map = req.dataMap

        map.putLong("timestamp", System.currentTimeMillis())

        payload.forEach { (k, v) ->
            when (v) {
                null -> {  }
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
        val req = putMap("/weather", args)
        dataClient(context).putDataItem(req.asPutDataRequest().setUrgent())
    }

    private fun sendTideToWatch(context: Context, args: Map<String, Any?>) {
        val req = putMap("/tide", args)
        dataClient(context).putDataItem(req.asPutDataRequest().setUrgent())
    }

    private fun sendTempToWatch(context: Context, args: Map<String, Any?>) {
        val req = putMap("/temp", args)
        dataClient(context).putDataItem(req.asPutDataRequest().setUrgent())
    }

    private fun sendFishingPointsToWatch(context: Context, args: Map<String, Any?>) {
        @Suppress("UNCHECKED_CAST")
        val points = (args["points"] as? List<Map<String, Any?>>) ?: emptyList()

        val req = PutDataMapRequest.create("/fishing_points")
        val map = req.dataMap

        map.putLong("timestamp", System.currentTimeMillis())

        val dmaps = ArrayList<DataMap>(points.size)
        for (p in points) {
            val dm = DataMap()

            dm.putString("name",      (p["name"] ?: "").toString())
            dm.putString("point_nm",  (p["point_nm"] ?: p["name"] ?: "").toString())
            dm.putString("addr",      (p["addr"] ?: "").toString())
            dm.putString("dpwt",      (p["dpwt"] ?: "").toString())
            dm.putString("material",  (p["material"] ?: "").toString())
            dm.putString("tide_time", (p["tide_time"] ?: "").toString())
            dm.putString("target",    (p["target"] ?: "").toString())
            dm.putString("point_dt",  (p["point_dt"] ?: "").toString())
            dm.putString("photo",     (p["photo"] ?: "").toString())

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
