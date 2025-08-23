package com.example.dive_app

import android.content.Context
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader

/**
 * CSV schema:
 * SE_NM, SGG_NM, SPOT_NM, STA_NM, GRDNT_VAL, SLANT_GRD_CD
 *
 * Put the file in: android/app/src/main/assets/
 * Default name is "coastal_slopes.csv"
 */
object CoastalSlopeRepo {

    private const val TAG = "CoastalSlopeRepo"
    private var assetFileName: String = "coastal_slopes.csv"

    data class Row(
        val seNm: String,        // 장소 유형
        val sggNm: String,       // 시군구
        val spotNm: String,      // 지점명
        val staNm: String,       // 장소명
        val gradient: Double,    // 경사 값
        val gradeCd: String      // 경사 등급
    )

    @Volatile private var loaded = false
    private val rows = mutableListOf<Row>()

    @Synchronized
    fun ensureLoaded(context: Context) {
        if (!loaded) {
            loadCsv(context)
            loaded = true
        }
    }

    // -------------------- 조회 기능 --------------------

    /** 특정 시군구에서 모든 지점 조회 */
    fun queryByRegion(regionQuery: String?): JSONArray {
        val region = regionQuery?.trim()?.lowercase() ?: ""
        val filtered = rows.filter { r -> region.isEmpty() || r.sggNm.lowercase().contains(region) }

        return JSONArray().apply {
            filtered.forEach { r ->
                put(JSONObject().apply {
                    put("se_nm", r.seNm)
                    put("sgg_nm", r.sggNm)
                    put("spot_nm", r.spotNm)
                    put("sta_nm", r.staNm)
                    put("gradient", r.gradient)
                    put("grade_cd", r.gradeCd)
                })
            }
        }
    }

    /** 경사도 기준으로 위험 지점 필터 */
    fun queryByGradient(min: Double): JSONArray {
        return JSONArray().apply {
            rows.filter { it.gradient >= min }.forEach { r ->
                put(JSONObject().apply {
                    put("se_nm", r.seNm)
                    put("sgg_nm", r.sggNm)
                    put("spot_nm", r.spotNm)
                    put("sta_nm", r.staNm)
                    put("gradient", r.gradient)
                    put("grade_cd", r.gradeCd)
                })
            }
        }
    }

    // -------------------- CSV Loader --------------------

    private fun loadCsv(context: Context) {
        rows.clear()
        try {
            context.assets.open(assetFileName).use { input ->
                BufferedReader(InputStreamReader(input, Charsets.UTF_8)).use { br ->
                    val header = splitCsv(br.readLine()?.removePrefix("\uFEFF") ?: return)
                    val idx = buildIndexMap(header)

                    var lineNo = 1
                    br.lineSequence().forEach { raw ->
                        lineNo++
                        val line = raw.trimEnd()
                        if (line.isBlank()) return@forEach

                        val cols = splitCsv(line)
                        if (cols.size < header.size) {
                            Log.w(TAG, "skip short line#$lineNo: $line")
                            return@forEach
                        }
                        try {
                            rows += Row(
                                seNm     = getCol(cols, idx.seNm).trim(),
                                sggNm    = getCol(cols, idx.sggNm).trim(),
                                spotNm   = getCol(cols, idx.spotNm).trim(),
                                staNm    = getCol(cols, idx.staNm).trim(),
                                gradient = getCol(cols, idx.gradient).toDoubleOrNull() ?: 0.0,
                                gradeCd  = getCol(cols, idx.gradeCd).trim()
                            )
                        } catch (e: Exception) {
                            Log.w(TAG, "skip line#$lineNo parse error: ${e.message}")
                        }
                    }
                }
            }
            Log.d(TAG, "Loaded rows: ${rows.size} from $assetFileName")
        } catch (e: Exception) {
            Log.e(TAG, "CSV load fail for $assetFileName", e)
        }
    }

    // -------------------- 보조 함수 --------------------

    private fun splitCsv(line: String): List<String> {
        val out = ArrayList<String>()
        val sb = StringBuilder()
        var inQuotes = false
        var i = 0
        while (i < line.length) {
            val c = line[i]
            when {
                c == '"' -> {
                    if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
                        sb.append('"'); i++
                    } else {
                        inQuotes = !inQuotes
                    }
                }
                c == ',' && !inQuotes -> {
                    out.add(sb.toString()); sb.setLength(0)
                }
                else -> sb.append(c)
            }
            i++
        }
        out.add(sb.toString())
        return out
    }

    private fun buildIndexMap(header: List<String>): Indexes {
        fun find(vararg names: String): Int {
            return header.indexOfFirst { h -> names.any { n -> h.equals(n, ignoreCase = true) } }
        }
        return Indexes(
            seNm     = find("SE_NM", "se_nm"),
            sggNm    = find("SGG_NM", "sgg_nm"),
            spotNm   = find("SPOT_NM", "spot_nm"),
            staNm    = find("STA_NM", "sta_nm"),
            gradient = find("GRDNT_VAL", "gradient"),
            gradeCd  = find("SLANT_GRD_CD", "slant_cd")
        )
    }

    private data class Indexes(
        val seNm: Int,
        val sggNm: Int,
        val spotNm: Int,
        val staNm: Int,
        val gradient: Int,
        val gradeCd: Int
    )

    private fun getCol(cols: List<String>, index: Int): String {
        return if (index in cols.indices) cols[index] else ""
    }
}
