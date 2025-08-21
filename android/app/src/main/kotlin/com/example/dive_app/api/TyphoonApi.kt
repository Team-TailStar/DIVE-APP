package com.example.dive_app.api

import android.util.Log
import com.example.dive_app.BuildConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.time.LocalDate
import java.time.format.DateTimeFormatter

object TyphoonApi {
    private const val BASE_URL = "http://apis.data.go.kr/1360000/TyphoonInfoService"
    private const val ENDPOINT = "getTyphoonInfo"

    // Put your key into BuildConfig via build.gradle(.kts) as DATA_GO_KR_SERVICE_KEY
    private val serviceKey: String = BuildConfig.DATA_GO_KR_SERVICE_KEY
    private val ymdFormatter: DateTimeFormatter = DateTimeFormatter.ofPattern("yyyyMMdd")

    /**
     * Fetch typhoon advisories in [from, to] (inclusive).
     * Returns JSONArray of items (possibly empty).
     */
    suspend fun fetchTyphoonInfo(
        from: LocalDate,
        to: LocalDate,
        pageNo: Int = 1,
        numOfRows: Int = 50,
        dataType: String = "JSON"
    ): JSONArray = withContext(Dispatchers.IO) {
        val fromStr = ymdFormatter.format(from)
        val toStr = ymdFormatter.format(to)

        // Avoid double-encoding: if the key already has %2B/%2F/%3D, use as-is
        val encodedKey = if (looksEncoded(serviceKey)) serviceKey
        else URLEncoder.encode(serviceKey, "UTF-8")

        val query = buildString {
            append("ServiceKey=").append(encodedKey)        // NOTE: capital S, K
            append("&pageNo=").append(pageNo)
            append("&numOfRows=").append(numOfRows)
            append("&dataType=").append(dataType)           // JSON or XML
            append("&fromTmFc=").append(fromStr)            // YYYYMMDD
            append("&toTmFc=").append(toStr)                // YYYYMMDD
        }

        val urlStr = "$BASE_URL/$ENDPOINT?$query"
        Log.d("TyphoonApi", "GET $urlStr")

        var conn: HttpURLConnection? = null
        try {
            conn = (URL(urlStr).openConnection() as HttpURLConnection).apply {
                requestMethod = "GET"
                connectTimeout = 15000
                readTimeout = 20000
            }

            val status = conn.responseCode
            val body = (if (status in 200..299) conn.inputStream else conn.errorStream)
                ?.bufferedReader()?.use { it.readText() }.orEmpty()

            Log.d("TyphoonApi", "status=$status, len=${body.length}")

            if (status != HttpURLConnection.HTTP_OK) {
                throw RuntimeException("Typhoon API HTTP $status: $body")
            }

            // ⛔ data.go.kr returns XML for errors even if you asked for JSON
            if (body.trimStart().startsWith("<")) {
                val code = Regex("<resultCode>(.*?)</resultCode>")
                    .find(body)?.groupValues?.get(1) ?: "UNKNOWN"
                val msg = Regex("<resultMsg>(.*?)</resultMsg>")
                    .find(body)?.groupValues?.get(1) ?: "UNKNOWN"
                Log.e("TyphoonApi", "API XML error: code=$code, msg=$msg")
                throw RuntimeException("OpenAPI $code: $msg")
            }

            if (!dataType.equals("JSON", ignoreCase = true)) {
                throw UnsupportedOperationException("XML parsing not implemented. Use dataType=JSON.")
            }

            // JSON happy path
            val root = JSONObject(body)
            val items = root
                .optJSONObject("response")
                ?.optJSONObject("body")
                ?.optJSONObject("items")
                ?.opt("item")

            return@withContext when (items) {
                is JSONArray -> items
                is JSONObject -> JSONArray().put(items)   // API sometimes returns a single object
                else -> JSONArray()                       // totalCount == 0
            }
        } finally {
            conn?.disconnect()
        }
    }

    /** Convenience: last [days] days (default 60). */
    suspend fun fetchRecent(days: Long = 60): JSONArray {
        val today = LocalDate.now()
        val from = today.minusDays(days)
        return fetchTyphoonInfo(from = from, to = today)
    }

    private fun looksEncoded(key: String): Boolean {
        return key.contains('%') ||
                key.contains("%2B", ignoreCase = true) ||
                key.contains("%3D", ignoreCase = true) ||
                key.contains("%2F", ignoreCase = true)
    }
}
