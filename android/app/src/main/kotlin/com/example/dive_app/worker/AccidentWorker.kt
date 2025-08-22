package com.example.dive_app.worker

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.example.dive_app.manager.AccidentAlertManager
import com.example.dive_app.util.getCurrentLocation

class AccidentWorker(ctx: Context, params: WorkerParameters) : CoroutineWorker(ctx, params) {
    override suspend fun doWork(): Result {
        val coords = getCurrentLocation(applicationContext)
        if (coords != null) {
            val (lat, lon) = coords
            AccidentAlertManager.checkAndNotify(
                context = applicationContext,
                lat = lat,
                lon = lon
            )
        }
        return Result.success()
    }
}