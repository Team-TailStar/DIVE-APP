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
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.launch
import com.example.dive_app.api.AirKoreaApi
import com.example.dive_app.api.WeatherApi
import com.example.dive_app.api.TideApi
import com.example.dive_app.api.FishingPointApi
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import org.json.JSONArray
import java.time.LocalDate
import com.example.dive_app.api.TyphoonApi

// 🔹 Flutter와 통신하기 위한 import
import io.flutter.plugin.common.MethodChannel

/**
 * FlutterActivity + WearOS 메시지 수신 로그
 * - 워치에서 날씨/조석/포인트/심박수 요청을 보냈을 때
 * - 폰이 수신하면 Logcat 출력 + Flutter로 전달
 */
class MainActivity : FlutterActivity(), MessageClient.OnMessageReceivedListener {

    // 🔹 Flutter와 연결할 채널 이름 (Flutter쪽 WatchConnectPage와 동일해야 함)
    private val CHANNEL = "com.example.dive_app/heart_rate"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
    }

    override fun onResume() {
        super.onResume()
        Wearable.getMessageClient(this).addListener(this)
        // 앱 실행시 워치에 심박수 요청 한번 전송
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
                lifecycleScope.launch {
                    try {
                        val data = AirKoreaApi.fetchAirQualityByLocation(context)
                        if (data != null) {
                            replyToWatch("/response_air_quality", data.toString())
                            Log.d("PhoneMsg", " 대기질 응답: ${data}")
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

                // suspend 함수라서 coroutine 필요
                CoroutineScope(Dispatchers.IO).launch {
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

                CoroutineScope(Dispatchers.IO).launch {
                    val tideArray = TideApi.fetchTideByLocation(this@MainActivity)
                    if (tideArray != null) {
                        val tideJson = JSONObject().apply {
                            put("tides", tideArray)   // ✅ 배열을 객체에 감싸줌
                        }
                        replyToWatch("/response_tide", tideJson.toString())
                        Log.d("PhoneMsg", "🌊 조석 응답 전송: $tideJson")
                    } else {
                        Log.e("PhoneMsg", "❌ 조석 데이터 조회 실패")
                    }
                }
            }

            "/request_point" -> {
                Log.d("PhoneMsg", "📩 워치에서 낚시포인트 요청 수신")

                CoroutineScope(Dispatchers.IO).launch {
                    val pointJson = FishingPointApi.fetchFishingPointByLocation(this@MainActivity)

                    if (pointJson != null) {
                        replyToWatch("/response_point", pointJson.toString())
                        Log.d("PhoneMsg", "🌊 낚시포인트 응답 전송: $pointJson")
                    } else {
                        Log.e("PhoneMsg", "❌ 낚시포인트 데이터 조회 실패")
                    }
                }
            }

            "/request_typhoon" -> {
                Log.d("PhoneMsg", "📩 워치에서 태풍 정보 요청 수신")

                CoroutineScope(Dispatchers.IO).launch {
                    try {
                        val to = LocalDate.now()
                        val from = to.minusDays(30)
                        val items: JSONArray = TyphoonApi.fetchTyphoonInfo(from, to, numOfRows = 100)


                        val payload = JSONObject().apply {
                            put("items", items)   // align with your tide style: wrap array in an object
                        }

                        replyToWatch("/response_typhoon", payload.toString())
                        Log.d("PhoneMsg", "🌀 태풍 응답 전송: $payload")
                    } catch (e: Exception) {
                        Log.e("PhoneMsg", "❌ 태풍 데이터 조회 실패: ${e.message}")
                        val err = JSONObject().apply {
                            put("error", e.message ?: "unknown error")
                        }
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

                    // 🔹 Flutter로 전달
                    MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, CHANNEL)
                        .invokeMethod("onHeartRate", bpm)

                } catch (e: Exception) {
                    Log.e("PhoneMsg", "⚠️ 심박수 파싱 실패: $data")
                }
            }

            else -> {
                Log.d("PhoneMsg", "📩 알 수 없는 path=$path , data=$data")
            }
        }
    }

    private fun replyToWatch(path: String, message: String) {
        Wearable.getNodeClient(this).connectedNodes
            .addOnSuccessListener { nodes ->
                nodes.forEach { node ->
                    Wearable.getMessageClient(this)
                        .sendMessage(node.id, path, message.toByteArray())
                        .addOnSuccessListener {
                            Log.d("PhoneMsg", "📨 워치로 응답 전송 성공 → $path , data=$message")
                        }
                        .addOnFailureListener { e ->
                            Log.e("PhoneMsg", "⚠️ 응답 전송 실패: ${e.message}")
                        }
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

    override fun onDestroy() {
        super.onDestroy()
    }
}
