package com.example.dive_app.worker

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.example.dive_app.manager.WeatherAlertManager
import com.example.dive_app.util.getCurrentLocation

class WeatherWorker(ctx: Context, params: WorkerParameters) : CoroutineWorker(ctx, params) {
    override suspend fun doWork(): Result {
        val coords = getCurrentLocation(applicationContext)
        if (coords != null) {
            val (lat, lon) = coords
            WeatherAlertManager.checkWeatherAlert(applicationContext, lat, lon)
        }
        return Result.success()
    }
}
