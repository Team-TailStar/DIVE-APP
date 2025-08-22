package com.example.dive_app.manager

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.example.dive_app.api.TyphoonApi
import com.google.android.gms.wearable.Wearable
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.pow
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * Typhoon proximity alert manager.
 * - Fetches recent typhoon positions from TyphoonApi.fetchRecent()
 * - Finds the NEAREST typhoon to (lat, lon)
 * - If within ALERT_KM, sends a message to Wear OS and (optionally) posts a phone notification
 *
 * Logcat tag: "TyphoonTest"
 */
object TyphoonAlertManager {

    private const val TAG = "TyphoonAlertManager"
    private const val TEST_TAG = "TyphoonTest"

    private const val WATCH_PATH = "/typhoon_alert"
    private const val CHANNEL_ID = "typhoon_alert_channel"
    private const val NOTIF_ID = 1001

    /** Alert radius in KM */
    private const val ALERT_KM = 300.0

    /**
     * Call this from an Activity/Service (e.g., inside a lifecycleScope.launch { ... }).
     *
     * @param context app or activity context
     * @param lat user latitude
     * @param lon user longitude
     * @param alsoNotifyPhone show a local phone notification in addition to sending a watch message
     */
    suspend fun checkTyphoonAlert(
        context: Context,
        lat: Double,
        lon: Double,
        alsoNotifyPhone: Boolean = false
    ) = withContext(Dispatchers.IO) {
        Log.d(TEST_TAG, "check start lat=$lat lon=$lon")

        runCatching {
            val arr: JSONArray = TyphoonApi.fetchRecent() ?: run {
                Log.d(TEST_TAG, "api result is null")
                return@withContext
            }

            val count = arr.length()
            Log.d(TEST_TAG, "api ok len=$count")
            if (count == 0) return@withContext

            var nearest: JSONObject? = null
            var nearestKm = Double.POSITIVE_INFINITY

            for (i in 0 until count) {
                val obj = arr.getJSONObject(i)
                val tyLat = obj.optDouble("typLat", Double.NaN)
                val tyLon = obj.optDouble("typLon", Double.NaN)
                val name = obj.optString("typName", "태풍")

                if (tyLat.isNaN() || tyLon.isNaN()) {
                    Log.w(TEST_TAG, "skip invalid coords index=$i name=$name lat=$tyLat lon=$tyLon")
                    continue
                }

                val km = haversine(lat, lon, tyLat, tyLon)
                if (km < nearestKm) {
                    nearestKm = km
                    nearest = obj
                }
            }

            if (nearest == null) {
                Log.d(TEST_TAG, "no valid typhoon coordinates")
                return@withContext
            }

            val name = nearest.optString("typName", "태풍")
            Log.d(TEST_TAG, "nearest=$name km=${"%.1f".format(nearestKm)}")

            if (nearestKm <= ALERT_KM) {
                val alertJson = buildTyphoonAlert(nearest)
                sendToWatch(context, alertJson)
                if (alsoNotifyPhone) {
                    postPhoneNotification(context, name, nearestKm)
                }
            } else {
                Log.d(TEST_TAG, "distance ${"%.1f".format(nearestKm)}km > ${ALERT_KM}km — no alert")
            }
        }.onFailure { e ->
            Log.e(TEST_TAG, "error: ${e.message}", e)
        }
    }

    /**
     * Manual test without hitting the API.
     * Triggers a fake alert toward the watch immediately.
     */
    fun sendTestAlert(context: Context) {
        val payload = JSONObject().apply {
            put("title", "태풍 링링 경보")
            put("message", "현재 일본 가고시마 동북동쪽 약 90 km 부근 육상\n중심 풍속 15m/s, 이동 ENE 방향(14km/h), 기압 1006hPa.\n\n이 태풍은 오늘(22일) 03시경 열대저압부로 약화되었으며, 이것으로 제12호 태풍 링링(LINGLING)에 대한 정보를 종료함.")
        }.toString()

        Log.d(TEST_TAG, "sendTestAlert payload=$payload")

        Wearable.getNodeClient(context).connectedNodes
            .addOnSuccessListener { nodes ->
                Log.d(TEST_TAG, "DRYRUN sending to ${nodes.size} node(s)")
                nodes.forEach { node ->
                    Wearable.getMessageClient(context)
                        .sendMessage(node.id, WATCH_PATH, payload.toByteArray())
                        .addOnSuccessListener { Log.d(TEST_TAG, "sent to ${node.displayName}/${node.id}") }
                        .addOnFailureListener { err -> Log.e(TEST_TAG, "send fail: ${err.message}", err) }
                }
            }
            .addOnFailureListener { e ->
                Log.e(TEST_TAG, "failed to get nodes: ${e.message}", e)
            }
    }

    private fun buildTyphoonAlert(obj: JSONObject): JSONObject {
        val name = obj.optString("typName", "태풍")
        val en = obj.optString("typEn", "")
        val loc = obj.optString("typLoc", "")
        val ws = obj.optInt("typWs", 0)
        val sp = obj.optInt("typSp", 0)
        val dir = obj.optString("typDir", "")
        val ps = obj.optInt("typPs", 0)
        val rem = obj.optString("rem", "")

        val title = "태풍 $name 경보"
        val message = "현재 $loc\n" +
                "중심 풍속 ${ws}m/s, 이동 $dir 방향(${sp}km/h), 기압 ${ps}hPa.\n\\n" +
                rem.replace("|", "\n")

        return JSONObject().apply {
            put("title", title)
            put("message", message.trim())
        }
    }

    // --- Helpers ---

    private suspend fun sendToWatch(context: Context, alertJson: JSONObject) {
        val payload = alertJson.toString()
        val nodes = Wearable.getNodeClient(context).connectedNodes.await()
        Log.d(TEST_TAG, "sending to ${nodes.size} node(s): $payload")

        val client = Wearable.getMessageClient(context)
        for (node in nodes) {
            runCatching {
                client.sendMessage(node.id, WATCH_PATH, payload.toByteArray()).await()
                Log.d(TEST_TAG, "sent to ${node.displayName}/${node.id}")
            }.onFailure { e ->
                Log.e(TEST_TAG, "send fail to ${node.displayName}/${node.id}: ${e.message}", e)
            }
        }
    }

    private fun postPhoneNotification(context: Context, typhoonName: String, distanceKm: Double) {
        ensureNotificationChannel(context)

        val text = "$typhoonName is within ${"%.0f".format(distanceKm)} km of your location."
        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            // Use a built-in icon to avoid resource errors. Replace with your own vector later.
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle("Typhoon alert")
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)

        NotificationManagerCompat.from(context).notify(NOTIF_ID, builder.build())
        Log.d(TEST_TAG, "phone notification posted")
    }

    private fun ensureNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val mgr = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val ch = NotificationChannel(
                CHANNEL_ID,
                "Typhoon Alerts",
                NotificationManager.IMPORTANCE_HIGH
            )
            mgr.createNotificationChannel(ch)
        }
    }

    /** Great-circle distance (km). */
    private fun haversine(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
        val R = 6371.0
        val dLat = Math.toRadians(lat2 - lat1)
        val dLon = Math.toRadians(lon2 - lon1)
        val a = sin(dLat / 2).pow(2.0) +
                cos(Math.toRadians(lat1)) * cos(Math.toRadians(lat2)) *
                sin(dLon / 2).pow(2.0)
        val c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return R * c
    }
}
