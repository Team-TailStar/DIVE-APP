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

object TideApi {
    private val baseURL = BuildConfig.API_BASE_URL
    private val serviceKey = BuildConfig.BADA_SERVICE_KEY

    suspend fun fetchTide(lat: Double, lon: Double): JSONArray? {
        return withContext(Dispatchers.IO) {
            try {
                val encodedKey = URLEncoder.encode(serviceKey, "UTF-8")
                val urlStr = "$baseURL/tide?lat=$lat&lon=$lon&key=$encodedKey"

                val conn = URL(urlStr).openConnection() as HttpURLConnection
                conn.requestMethod = "GET"

                val res = conn.inputStream.bufferedReader().use { it.readText() }
                Log.d("TideApi", "fetchTide raw: $res")

                JSONArray(res)
            } catch (e: Exception) {
                Log.e("TideApi", "fetchTide 실패", e)
                null
            }
        }
    }

    // 📌 현재 위치 기반으로 조석 데이터 조회
    @SuppressLint("MissingPermission")
    suspend fun fetchTideByLocation(context: Context): JSONArray? {
        return try {
            val fused = LocationServices.getFusedLocationProviderClient(context)
            val location = try {
                fused.lastLocation.await()
            } catch (e: Exception) {
                Log.w("TideApi", "⚠️ 위치 가져오기 실패 → 기본 좌표(서울) 사용", e)
                null
            }

            val lat = location?.latitude ?: 37.5665
            val lon = location?.longitude ?: 126.9780

            fetchTide(lat, lon)
        } catch (e: Exception) {
            Log.e("TideApi", "❌ fetchTideByLocation 실패", e)
            null
        }
    }
}
