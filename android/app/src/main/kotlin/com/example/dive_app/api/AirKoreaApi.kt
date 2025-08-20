package com.example.dive_app.api

import android.annotation.SuppressLint
import android.content.Context
import android.location.Geocoder
import android.util.Log
import com.google.android.gms.location.LocationServices
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.util.Locale
import kotlinx.coroutines.tasks.await
import com.example.dive_app.BuildConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

object AirKoreaApi {
    private const val host = "apis.data.go.kr"
    private const val path = "/B552584/ArpltnInforInqireSvc/getCtprvnRltmMesureDnsty"
    private val serviceKey = BuildConfig.AIRKOREA_SERVICE_KEY

    // 🔥 suspend 추가
    suspend fun fetchAirQuality(sidoName: String): JSONObject? {
        return withContext(Dispatchers.IO) {   // ✅ IO 스레드에서 실행
            try {
                val encodedKey = URLEncoder.encode(serviceKey, "UTF-8")
                val encodedSido = URLEncoder.encode(sidoName, "UTF-8")

                val urlStr = "https://apis.data.go.kr$path?" +
                        "serviceKey=$encodedKey&returnType=json&sidoName=$encodedSido" +
                        "&numOfRows=1&pageNo=1&ver=1.3"

                val conn = URL(urlStr).openConnection() as HttpURLConnection
                conn.requestMethod = "GET"

                val res = conn.inputStream.bufferedReader().use { it.readText() }

                Log.d("AirKoreaApi", "raw response: $res")

                JSONObject(res)  // ✅ 이제 결과 JSON 리턴 가능
            } catch (e: Exception) {
                Log.e("AirKoreaApi", "fetchAirQuality 실패", e)
                null
            }
        }
    }

    @SuppressLint("MissingPermission")
    suspend fun fetchAirQualityByLocation(context: Context): JSONObject? {
        return try {
            val fused = LocationServices.getFusedLocationProviderClient(context)
            val location = fused.lastLocation.await()

            val geocoder = Geocoder(context, Locale.KOREA)
            val addr = location?.let {
                geocoder.getFromLocation(it.latitude, it.longitude, 1)
            }
            val adminArea = addr?.firstOrNull()?.adminArea ?: "서울"
            val sidoName = normalizeRegion(adminArea)

            // ✅ 원본 JSON 받아오기
            val rawJson: JSONObject? = fetchAirQuality(sidoName)

            if (rawJson != null) {
                val response = rawJson.getJSONObject("response")
                val body = response.getJSONObject("body")
                val items = body.getJSONArray("items")

                if (items.length() > 0) {
                    val first = items.getJSONObject(0)

                    // ✅ 필요한 값만 추출해서 리턴
                    JSONObject().apply {
                        put("pm10Value", first.optString("pm10Value"))
                        put("pm10Grade", first.optString("pm10Grade1h"))
                        put("pm25Value", first.optString("pm25Value"))
                        put("pm25Grade", first.optString("pm25Grade1h"))
                        put("o3Value", first.optString("o3Value"))
                        put("o3Grade", first.optString("o3Grade"))
                        put("no2Value", first.optString("no2Value"))
                        put("no2Grade", first.optString("no2Grade"))
                    }
                } else {
                    null
                }
            } else {
                null
            }
        } catch (e: Exception) {
            Log.e("AirKoreaApi", "위치 기반 대기질 조회 실패", e)
            null
        }
    }

    private fun normalizeRegion(adminArea: String): String {
        val s = adminArea.replace("특별시", "")
            .replace("광역시", "")
            .replace("특별자치도", "")
            .replace("특별자치시", "")
            .replace("도", "")
            .trim()

        return when {
            s.contains("서울") -> "서울"
            s.contains("부산") -> "부산"
            s.contains("대구") -> "대구"
            s.contains("인천") -> "인천"
            s.contains("광주") -> "광주"
            s.contains("대전") -> "대전"
            s.contains("울산") -> "울산"
            s.contains("세종") -> "세종"
            s.contains("경기") -> "경기"
            s.contains("강원") -> "강원"
            s.contains("충북") -> "충북"
            s.contains("충남") -> "충남"
            s.contains("전북") -> "전북"
            s.contains("전남") -> "전남"
            s.contains("경북") -> "경북"
            s.contains("경남") -> "경남"
            s.contains("제주") -> "제주"
            else -> "서울"
        }
    }
}

