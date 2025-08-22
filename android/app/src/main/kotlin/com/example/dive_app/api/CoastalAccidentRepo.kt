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
    private var assetFileName: String = "coastal_accidents_2022.csv"

    data class Row(
        val placeNm: String,
        val placeSeNm: String,
        val total: Int,
        val y2017: Int,
        val y2018: Int,
        val y2019: Int,
        val y2020: Int
    )

    @Volatile private var loaded = false
    private val rows = mutableListOf<Row>()

    /** If you keep a Korean file name, call this before ensureLoaded: setAssetFileName("연안_장소별_사고발생이력_2022.csv") */
    fun setAssetFileName(name: String) {
        assetFileName = name
        loaded = false
    }

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

    // -------------------- Queries --------------------

    /**
     * regionQuery: substring match against PLACE_NM (e.g., "부산", "강원도").
     * placeType: exact match against PLACE_SE_NM (e.g., "방파제"). Pass null to ignore.
     *
     * Returns:
     * {
     *   "items": [ {place_nm, place_se_nm, accidents, y2017..y2020}, ... ],
     *   "summary": {
     *     "total": <int>,
     *     "by_type": [ {"place_se_nm": "...", "accidents": <int>}, ... ]
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

        val items = JSONArray().apply {
            filtered.forEach { r ->
                put(JSONObject().apply {
                    put("place_nm", r.placeNm)
                    put("place_se_nm", r.placeSeNm)
                    put("accidents", r.total)
                    put("y2017", r.y2017)
                    put("y2018", r.y2018)
                    put("y2019", r.y2019)
                    put("y2020", r.y2020)
                })
            }
        }

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

    /** Top N PLACE_SE_NM by accidents. If regionQuery is non-empty, restrict to that region. */
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
                    var header = br.readLine() ?: return
                    header = header.removePrefix("\uFEFF") // strip BOM if present

                    val headerCols = splitCsv(header).map { it.trim() }
                    val idx = buildIndexMap(headerCols)

                    var lineNo = 1
                    br.lineSequence().forEach { raw ->
                        lineNo++
                        val line = raw.trimEnd()
                        if (line.isBlank()) return@forEach

                        val cols = splitCsv(line)
                        if (cols.size < headerCols.size) {
                            Log.w(TAG, "skip short line#$lineNo: $line")
                            return@forEach
                        }
                        try {
                            rows += Row(
                                placeNm   = getCol(cols, idx.placeNm).trim(),
                                placeSeNm = getCol(cols, idx.placeSeNm).trim(),
                                total     = getCol(cols, idx.total).toIntOrNull() ?: 0,
                                y2017     = getCol(cols, idx.y2017).toIntOrNull() ?: 0,
                                y2018     = getCol(cols, idx.y2018).toIntOrNull() ?: 0,
                                y2019     = getCol(cols, idx.y2019).toIntOrNull() ?: 0,
                                y2020     = getCol(cols, idx.y2020).toIntOrNull() ?: 0
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

    // Robust-ish CSV splitter (handles quotes and escaped quotes)
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

    // Map header names → indices (case-insensitive). Falls back to default positions if needed.
    private fun buildIndexMap(header: List<String>): Indexes {
        fun find(vararg names: String): Int {
            val idx = header.indexOfFirst { h -> names.any { n -> h.equals(n, ignoreCase = true) } }
            return if (idx >= 0) idx else -1
        }

        var iPlaceNm   = find("PLACE_NM", "place_nm")
        var iPlaceSeNm = find("PLACE_SE_NM", "place_se_nm")
        var iTotal     = find("ACC_CQT_SUM", "acc_cqt_sum")
        var i2017      = find("Y2017_ACC_CQT_SUM", "y2017_acc_cqt_sum")
        var i2018      = find("Y2018_ACC_CQT_SUM", "y2018_acc_cqt_sum")
        var i2019      = find("Y2019_ACC_CQT_SUM", "y2019_acc_cqt_sum")
        var i2020      = find("Y2020_ACC_CQT_SUM", "y2020_acc_cqt_sum")

        // If header names are unknown but order matches, fall back to 0..6
        if (listOf(iPlaceNm, iPlaceSeNm, iTotal, i2017, i2018, i2019, i2020).any { it == -1 } && header.size >= 7) {
            iPlaceNm = 0; iPlaceSeNm = 1; iTotal = 2; i2017 = 3; i2018 = 4; i2019 = 5; i2020 = 6
            Log.w(TAG, "Header names not recognized; falling back to positional indices 0..6")
        }

        return Indexes(iPlaceNm, iPlaceSeNm, iTotal, i2017, i2018, i2019, i2020)
    }

    private data class Indexes(
        val placeNm: Int,
        val placeSeNm: Int,
        val total: Int,
        val y2017: Int,
        val y2018: Int,
        val y2019: Int,
        val y2020: Int
    )

    private fun getCol(cols: List<String>, index: Int): String {
        return if (index in cols.indices) cols[index] else ""
    }
}
