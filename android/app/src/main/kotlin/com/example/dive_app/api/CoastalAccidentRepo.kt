package com.example.dive_app

import android.content.Context
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader

/**
 * CSV schema (7 columns expected):
 * PLACE_NM, PLACE_SE_NM, ACC_CQT_SUM,
 * Y2017_ACC_CQT_SUM, Y2018_ACC_CQT_SUM, Y2019_ACC_CQT_SUM, Y2020_ACC_CQT_SUM
 *
 * Put the file in: android/app/src/main/assets/
 * Default name is "coastal_accidents_2022.csv" (change with setAssetFileName if needed).
 */
object CoastalAccidentRepo {

    private const val TAG = "CoastalAccidentRepo"
    private var assetFileName: String = "coastal_accidents.csv"

    data class Row(
        val placeNm: String,
        val placeSeNm: String,
        val total: Int
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

    @Synchronized
    fun reload(context: Context) {
        loaded = false
        rows.clear()
        loadCsv(context)
        loaded = true
    }

    // -------------------- 조회 기능 --------------------
    /**
     * 지역/장소유형별 조회
     * @param regionQuery 지역명 부분 검색 (예: "부산")
     * @param placeType   장소 유형 필터 (예: "갯바위")
     *
     * 반환 JSON 구조:
     * {
     *   "items": [ {place_nm, place_se_nm, accidents}, ... ],
     *   "summary": {
     *     "total": <총합>,
     *     "by_type": [ {"place_se_nm": ..., "accidents": ...}, ... ]
     *   }
     * }
     */
    fun queryByRegion(regionQuery: String?, placeType: String?): JSONObject {
        val region = regionQuery?.trim()?.lowercase() ?: ""
        val type   = placeType?.trim()?.lowercase()

        val filtered = rows.filter { r ->
            val regionOk = region.isEmpty() || r.placeNm.lowercase().contains(region)
            val typeOk   = type.isNullOrEmpty() || r.placeSeNm.lowercase() == type
            regionOk && typeOk
        }

        // 개별 항목
        val items = JSONArray().apply {
            filtered.forEach { r ->
                put(JSONObject().apply {
                    put("place_nm", r.placeNm)
                    put("place_se_nm", r.placeSeNm)
                    put("accidents", r.total)
                })
            }
        }

        // 유형별 합계
        val byType = JSONArray().apply {
            filtered.groupBy { it.placeSeNm }
                .mapValues { (_, v) -> v.sumOf { it.total } }
                .toList()
                .sortedByDescending { it.second }
                .forEach { (typeName, sum) ->
                    put(JSONObject().apply {
                        put("place_se_nm", typeName)
                        put("accidents", sum)
                    })
                }
        }

        return JSONObject().apply {
            put("items", items)
            put("summary", JSONObject().apply {
                put("total", filtered.sumOf { it.total })
                put("by_type", byType)
            })
        }
    }

    /** 특정 지역에서 유형별 Top N */
    fun topByType(regionQuery: String?, limit: Int = 5): JSONArray {
        val region = regionQuery?.trim()?.lowercase() ?: ""
        val base = if (region.isEmpty()) rows else rows.filter { it.placeNm.lowercase().contains(region) }

        return JSONArray().apply {
            base.groupBy { it.placeSeNm }
                .mapValues { (_, v) -> v.sumOf { it.total } }
                .toList()
                .sortedByDescending { it.second }
                .take(limit)
                .forEach { (typeName, sum) ->
                    put(JSONObject().apply {
                        put("place_se_nm", typeName)
                        put("accidents", sum)
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
                                placeNm   = getCol(cols, idx.placeNm).trim(),
                                placeSeNm = getCol(cols, idx.placeSeNm).trim(),
                                total     = getCol(cols, idx.total).toIntOrNull() ?: 0
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

    /** CSV 라인 파서 */
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
                        sb.append('"'); i++ // escaped quote
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

    /** 헤더 이름 → 인덱스 매핑 */
    private fun buildIndexMap(header: List<String>): Indexes {
        fun find(vararg names: String): Int {
            return header.indexOfFirst { h -> names.any { n -> h.equals(n, ignoreCase = true) } }
        }

        var iPlaceNm   = find("PLACE_NM", "place_nm")
        var iPlaceSeNm = find("PLACE_SE_NM", "place_se_nm")
        var iTotal     = find("ACC_CQT_SUM", "acc_cqt_sum")

        if (listOf(iPlaceNm, iPlaceSeNm, iTotal).any { it == -1 }) {
            // fallback: 기본 위치
            iPlaceNm = 0; iPlaceSeNm = 1; iTotal = 2
            Log.w(TAG, "Header names not recognized; using default indices 0..2")
        }

        return Indexes(iPlaceNm, iPlaceSeNm, iTotal)
    }

    private data class Indexes(
        val placeNm: Int,
        val placeSeNm: Int,
        val total: Int
    )

    private fun getCol(cols: List<String>, index: Int): String {
        return if (index in cols.indices) cols[index] else ""
    }
}
