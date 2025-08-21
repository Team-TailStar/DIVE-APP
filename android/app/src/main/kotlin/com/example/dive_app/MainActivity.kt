package com.example.dive_app

import android.annotation.SuppressLint
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import com.google.android.gms.wearable.Wearable
import com.google.android.gms.wearable.MessageClient
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.location.LocationServices
import org.json.JSONObject
import org.json.JSONArray
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.time.LocalDate
import com.example.dive_app.api.AirKoreaApi
import com.example.dive_app.api.WeatherApi
import com.example.dive_app.api.TideApi
import com.example.dive_app.api.FishingPointApi
import com.example.dive_app.api.TyphoonApi
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity(), MessageClient.OnMessageReceivedListener {

    private val CHANNEL = "com.example.dive_app/heart_rate"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
    }

    // ✅ keep a single onResume
    override fun onResume() {
        super.onResume()
        Wearable.getMessageClient(this).addListener(this)

        // 앱 실행 시 테스트 1회 (워치 없이도 확인)
        debugTyphoonOnce()

        // (기존 동작) 워치에 심박수 요청
        replyToWatch("/request_heart_rate", "request")
    }

    override fun onPause() {
        super.onPause()
        Wearable.getMessageClient(this).removeListener(this)
    }

    override fun onMessageReceived(messageEvent: MessageEvent) {
        val path = messageEvent.path
        val data = String(messageEvent.data)

        when (path) {
            "/request_air_quality" -> {
                Log.d("PhoneMsg", "📩 워치에서 미세먼지 요청 수신")
                lifecycleScope.launch(Dispatchers.IO) {
                    try {
                        // ❗️fix: use this@MainActivity instead of 'context'
                        val res = AirKoreaApi.fetchAirQualityByLocation(this@MainActivity)
                        if (res != null) {
                            replyToWatch("/response_air_quality", res.toString())
                            Log.d("PhoneMsg", "🌫️ 대기질 응답: $res")
                        } else {
                            Log.e("PhoneMsg", "❌ 대기질 데이터 없음")
                        }
                    } catch (e: Exception) {
                        Log.e("PhoneMsg", "⚠️ 대기질 조회 실패: ${e.message}")
                    }
                }
            }

            "/request_location" -> {
                Log.d("PhoneMsg", "📩 워치에서 현재 위치 요청 수신")
                responseCurrentLocation()
            }

            "/request_weather" -> {
                Log.d("PhoneMsg", "📩 워치에서 날씨 요청 수신")
                lifecycleScope.launch(Dispatchers.IO) {
                    val weatherJson = WeatherApi.fetchWeather(this@MainActivity)
                    if (weatherJson != null) {
                        Log.d("PhoneMsg", "🌤️ 날씨 데이터 준비됨 → $weatherJson")
                        replyToWatch("/response_weather", weatherJson.toString())
                    } else {
                        Log.e("PhoneMsg", "❌ 날씨 데이터 불러오기 실패")
                    }
                }
            }

            "/request_tide" -> {
                Log.d("PhoneMsg", "📩 워치에서 조석 요청 수신")
                lifecycleScope.launch(Dispatchers.IO) {
                    val tideArray = TideApi.fetchTideByLocation(this@MainActivity)
                    if (tideArray != null) {
                        val tideJson = JSONObject().apply { put("tides", tideArray) }
                        replyToWatch("/response_tide", tideJson.toString())
                        Log.d("PhoneMsg", "🌊 조석 응답 전송: count=${tideArray.length()}")
                    } else {
                        Log.e("PhoneMsg", "❌ 조석 데이터 조회 실패")
                    }
                }
            }

            "/request_point" -> {
                Log.d("PhoneMsg", "📩 워치에서 낚시포인트 요청 수신")
                lifecycleScope.launch(Dispatchers.IO) {
                    val pointJson = FishingPointApi.fetchFishingPointByLocation(this@MainActivity)
                    if (pointJson != null) {
                        replyToWatch("/response_point", pointJson.toString())
                        Log.d("PhoneMsg", "📍 포인트 응답 전송")
                    } else {
                        Log.e("PhoneMsg", "❌ 포인트 데이터 조회 실패")
                    }
                }
            }

            "/request_typhoon" -> {
                Log.d("PhoneMsg", "📩 워치에서 태풍 정보 요청 수신")
                lifecycleScope.launch(Dispatchers.IO) {
                    try {
                        val to = LocalDate.now()
                        val from = to.minusDays(30)
                        val items: JSONArray = TyphoonApi.fetchTyphoonInfo(from, to, numOfRows = 100)
                        val payload = JSONObject().apply { put("items", items) }

                        replyToWatch("/response_typhoon", payload.toString())
                        // concise Logcat
                        Log.d("TyphoonTest", "✅ count=${items.length()}")
                        if (items.length() > 0) {
                            Log.d("TyphoonTest", "first=${items.getJSONObject(0)}")
                        }
                    } catch (e: Exception) {
                        Log.e("TyphoonTest", "❌ 태풍 조회 실패: ${e.message}")
                        val err = JSONObject().apply { put("error", e.message ?: "unknown error") }
                        replyToWatch("/response_typhoon", err.toString())
                    }
                }
            }

            "/response_heart_rate" -> {
                Log.d("PhoneMsg", "📩 워치에서 심박수 수신")
                try {
                    val json = JSONObject(data)
                    val bpm = json.getInt("heart_rate")
                    Log.d("PhoneMsg", "❤️ 워치에서 심박수 수신: $bpm bpm")
                    MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, CHANNEL)
                        .invokeMethod("onHeartRate", bpm)
                } catch (e: Exception) {
                    Log.e("PhoneMsg", "⚠️ 심박수 파싱 실패: $data")
                }
            }

            else -> Log.d("PhoneMsg", "📩 알 수 없는 path=$path , data=$data")
        }
    }

    private fun replyToWatch(path: String, message: String) {
        Wearable.getNodeClient(this).connectedNodes
            .addOnSuccessListener { nodes ->
                nodes.forEach { node ->
                    Wearable.getMessageClient(this)
                        .sendMessage(node.id, path, message.toByteArray())
                        .addOnSuccessListener {
                            Log.d("PhoneMsg", "📨 워치로 응답 전송 성공 → $path")
                        }
                        .addOnFailureListener { e ->
                            Log.e("PhoneMsg", "⚠️ 응답 전송 실패: ${e.message}")
                        }
                }
            }
    }

    private fun debugTyphoonOnce() {
        lifecycleScope.launch(Dispatchers.IO) {
            try {
                val to = LocalDate.now()
                val from = to.minusDays(2)
                val items = TyphoonApi.fetchTyphoonInfo(from, to, pageNo = 1, numOfRows = 100)

                Log.d("TyphoonTest", "count=${items.length()}")
                if (items.length() > 0) {
                    Log.d("TyphoonTest", "first=${items.getJSONObject(0)}")
                }
            } catch (e: Exception) {
                Log.e("TyphoonTest", "ERR: ${e.message}")
            }
        }
    }

    @SuppressLint("MissingPermission")
    private fun responseCurrentLocation() {
        val fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        fusedLocationClient.lastLocation
            .addOnSuccessListener { location ->
                if (location != null) {
                    val locationJson = JSONObject().apply {
                        put("lat", location.latitude)
                        put("lon", location.longitude)
                    }
                    replyToWatch("/response_location", locationJson.toString())
                    Log.d("PhoneMsg", "📨 현재 위치 응답 전송: $locationJson")
                } else {
                    Log.w("PhoneMsg", "⚠️ 위치 정보를 가져올 수 없음")
                }
            }
            .addOnFailureListener { e ->
                Log.e("PhoneMsg", "⚠️ 위치 요청 실패: ${e.message}")
            }
    }
}
