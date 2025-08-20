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
                val weatherJson = JSONObject().apply {
                    put("sky", "맑음")
                    put("temp", "27")
                    put("humidity", "65%")
                    put("windspd", "3.2m/s")
                    put("rain", "0mm")
                    put("winddir", "NE")
                    put("waveHt", "0.5m")
                    put("waveDir", "동쪽")
                    put("obsWt", "24.5")
                }
                replyToWatch("/response_weather", weatherJson.toString())
            }

            "/request_tide" -> {
                Log.d("PhoneMsg", "📩 워치에서 조석 요청 수신")
                val tidesArray = listOf(
                    JSONObject().apply {
                        put("pThisDate", "2025-8-19-화-7-3")
                        put("pName", "부산")
                        put("pMul", "4물")
                        put("pSun", "05:51/19:00")
                        put("pMoon", "07:32/19:59")
                        put("jowi1", "03:10")
                        put("jowi2", "12:30")
                        put("jowi3", "18:40")
                        put("jowi4", "")
                    },
                    JSONObject().apply {
                        put("pThisDate", "2025-8-20-수-6-3")
                        put("pName", "부산")
                        put("pMul", "4물")
                        put("pSun", "05:51/19:00")
                        put("pMoon", "07:32/19:59")
                        put("jowi1", "03:10")
                        put("jowi2", "12:30")
                        put("jowi3", "18:40")
                        put("jowi4", "")
                    }
                )

                val tideJson = JSONObject().apply {
                    put("tides", tidesArray)
                }
                replyToWatch("/response_tide", tideJson.toString())
            }

            "/request_point" -> {
                Log.d("PhoneMsg", "📩 워치에서 포인트 요청 수신")
                val pointsArray = listOf(
                    JSONObject().apply {
                        put("name", "부산광역시")
                        put("point_nm", "광안리 해수욕장")
                        put("dpwt", "5m")
                        put("material", "모래")
                        put("tide_time", "4물")
                        put("target", "숭어, 도다리")
                        put("lat", 35.1532)
                        put("lon", 129.1186)
                        put("point_dt", "5 km")
                    },
                    JSONObject().apply {
                        put("name", "부산광역시")
                        put("point_nm", "다대포")
                        put("dpwt", "7m")
                        put("material", "자갈")
                        put("tide_time", "5물")
                        put("target", "우럭, 노래미")
                        put("lat", 35.0450)
                        put("lon", 128.9631)
                        put("point_dt", "5 km")
                    }
                )

                val pointsJson = JSONObject().apply {
                    put("points", pointsArray)
                }
                replyToWatch("/response_point", pointsJson.toString())
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
