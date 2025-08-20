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

object WeatherApi {
    private val baseURL = BuildConfig.API_BASE_URL
    private val serviceKey = BuildConfig.BADA_SERVICE_KEY

    /**
     * ✅ 기상 (현재 날씨 API)
     */
    suspend fun fetchBaseWeather(lat: Double, lon: Double): JSONObject? {
        return withContext(Dispatchers.IO) {
            try {
                val encodedKey = URLEncoder.encode(serviceKey, "UTF-8")
                val urlStr = "$baseURL/current?lat=$lat&lon=$lon&key=$encodedKey"

                val conn = URL(urlStr).openConnection() as HttpURLConnection
                conn.requestMethod = "GET"

                val res = conn.inputStream.bufferedReader().use { it.readText() }
                Log.d("WeatherApi", "fetchBaseWeather raw: $res")

                JSONObject(res)
            } catch (e: Exception) {
                Log.e("WeatherApi", "fetchBaseWeather 실패", e)
                null
            }
        }
    }

    /**
     * ✅ 해양 (수온 API)
     */
    suspend fun fetchSeaTemp(lat: Double, lon: Double): JSONObject? {
        return withContext(Dispatchers.IO) {
            try {
                val encodedKey = URLEncoder.encode(serviceKey, "UTF-8")
                val urlStr = "$baseURL/temp?lat=$lat&lon=$lon&key=$encodedKey"

                val conn = URL(urlStr).openConnection() as HttpURLConnection
                conn.requestMethod = "GET"

                val res = conn.inputStream.bufferedReader().use { it.readText() }
                Log.d("WeatherApi", "fetchSeaWeather raw: $res")

                // 응답은 배열 → 첫 번째만 꺼내서 JSONObject로 감싸줌
                val arr = org.json.JSONArray(res)
                if (arr.length() > 0) arr.getJSONObject(0) else null
            } catch (e: Exception) {
                Log.e("WeatherApi", "fetchSeaWeather 실패", e)
                null
            }
        }
    }

    /**
     * ✅ 해양날씨
     */
    suspend fun fetchSeaWeather(lat: Double, lon: Double): JSONObject? {
        return withContext(Dispatchers.IO) {
            try {
                val encodedKey = URLEncoder.encode(serviceKey, "UTF-8")
                val urlStr = "$baseURL/forecast?lat=$lat&lon=$lon&key=$encodedKey"

                val conn = URL(urlStr).openConnection() as HttpURLConnection
                conn.requestMethod = "GET"

                val res = conn.inputStream.bufferedReader().use { it.readText() }
                val cleanRes = res.replace(Regex("[\\uFEFF\\u200B\\u200C\\u200D]"), "")
                Log.d("WeatherApi", "fetchSeaWeather raw: $cleanRes")

                val arr = org.json.JSONArray(cleanRes)
                if (arr.length() > 0) arr.getJSONObject(0) else null
            } catch (e: Exception) {
                Log.e("WeatherApi", "fetchSeaWeather 실패", e)
                null
            }
        }
    }

    /**
     * ✅ 현위치 기반 날씨 + 수온 종합
     * - 위치 못 받으면 기본값 "서울" 좌표 사용
     * - 필요한 필드만 뽑아서 JSONObject로 리턴
     */
    @SuppressLint("MissingPermission")
    suspend fun fetchWeather(context: Context): JSONObject? {
        return try {
            val fused = LocationServices.getFusedLocationProviderClient(context)

            // 📌 위치 안전하게 가져오기
            val location = try {
                fused.lastLocation.await()
            } catch (e: Exception) {
                Log.w("WeatherApi", "⚠️ 위치 가져오기 실패 → 기본 좌표(서울) 사용", e)
                null
            }

            // 📌 못 받으면 서울 좌표로 대체
            val lat = location?.latitude ?: 37.5665    // 서울 위도
            val lon = location?.longitude ?: 126.9780  // 서울 경도

            // ✅ 각각 호출
            val baseJson = fetchBaseWeather(lat, lon)
            val seaTempJson = fetchSeaTemp(lat, lon)
            val seaJson = fetchSeaWeather(lat, lon)

            if (baseJson != null) {
                val weatherArr = baseJson.optJSONArray("weather")
                val firstWeather = weatherArr?.optJSONObject(0)

                // ✅ 필요한 값만 추출해서 묶기
                JSONObject().apply {

                    put("sky", firstWeather?.optString("sky") ?: "")
                    put("temp", firstWeather?.optString("temp") ?: "")
                    put("humidity", firstWeather?.optString("humidity") ?: "")
                    put("windspd", firstWeather?.optString("windspd") ?: "")
                    put("rain", firstWeather?.optString("rain") ?: "")
                    put("winddir", firstWeather?.optString("winddir") ?: "")
                    put("waveHt", seaJson?.optString("waveHt") ?: "")
                    put("waveDir", seaJson?.optString("waveDir") ?: "")

                    // 🌊 해양 수온 값 추가
                    put("obsWt", seaTempJson?.optString("obs_wt") ?: "")
                }
            } else {
                null
            }
        } catch (e: Exception) {
            Log.e("WeatherApi", "fetchWeather 실패", e)
            null
        }
    }
}
