package com.example.dive_app.api

import android.annotation.SuppressLint
import android.content.Context
import android.util.Log
import com.google.android.gms.location.LocationServices
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import kotlinx.coroutines.tasks.await
import com.example.dive_app.BuildConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray

object FishingPointApi {
    private val baseURL = BuildConfig.API_BASE_URL
    private val serviceKey = BuildConfig.BADA_SERVICE_KEY

    // Modified to return a JSONObject that contains only the filtered fishing points
    suspend fun fetchFishingPoints(lat: Double, lon: Double): JSONObject? {
        return withContext(Dispatchers.IO) {
            try {
                val encodedKey = URLEncoder.encode(serviceKey, "UTF-8")
                val urlStr = "$baseURL/point?lat=$lat&lon=$lon&key=$encodedKey"

                val conn = URL(urlStr).openConnection() as HttpURLConnection
                conn.requestMethod = "GET"

                val res = conn.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }

                val cleanRes = res
                    .replace("\uFEFF", "")
                    .replace(Regex("[\\u0000-\\u001F\\u007F]"), "")

                Log.d("FishingPointApi", "📥 Raw Response: $res")
                Log.d("FishingPointApi", "✅ Cleaned Response: $cleanRes")

                val fullResponseJson = JSONObject(cleanRes)
                val fishingPointsArray = fullResponseJson.optJSONArray("fishing_point")

                val filteredFishingPoints = JSONArray()

                if (fishingPointsArray != null) {
                    for (i in 0 until fishingPointsArray.length()) {
                        val originalPoint = fishingPointsArray.getJSONObject(i)
                        val filteredPoint = JSONObject().apply {
                            put("name", originalPoint.optString("name"))
                            put("point_nm", originalPoint.optString("point_nm"))
                            put("dpwt", originalPoint.optString("dpwt"))
                            put("material", originalPoint.optString("material"))
                            put("tide_time", originalPoint.optString("tide_time"))
                            put("target", originalPoint.optString("target"))
                            put("lat", originalPoint.optString("lat"))
                            put("lon", originalPoint.optString("lon"))
                            put("point_dt", originalPoint.optString("point_dt"))
                        }
                        filteredFishingPoints.put(filteredPoint)
                    }
                }

                val resultObject = JSONObject().apply {
                    put("points", filteredFishingPoints)
                }

                return@withContext resultObject

            } catch (e: Exception) {
                Log.e("FishingPointApi", "❌ fetchFishingPoints 실패", e)
                null
            }
        }
    }

    @SuppressLint("MissingPermission")
    suspend fun fetchFishingPointByLocation(context: Context): JSONObject? {
        return try {
            val fused = LocationServices.getFusedLocationProviderClient(context)
            val location = try {
                fused.lastLocation.await()
            } catch (e: Exception) {
                Log.w("FishingPointApi", "⚠️ 위치 가져오기 실패 → 기본 좌표(서울) 사용", e)
                null
            }

            val lat = location?.latitude ?: 37.5665
            val lon = location?.longitude ?: 126.9780

            fetchFishingPoints(lat, lon)
        } catch (e: Exception) {
            Log.e("FishingPointApi", "❌ fetchFishingPointByLocation 실패", e)
            null
        }
    }
}