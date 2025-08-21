package com.example.dive_app.worker

import android.annotation.SuppressLint
import android.content.Context
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.example.dive_app.manager.TyphoonAlertManager
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit
import androidx.work.PeriodicWorkRequestBuilder
import com.example.dive_app.util.getCurrentLocation

class TyphoonWorker(
    appContext: Context,
    workerParams: WorkerParameters
) : CoroutineWorker(appContext, workerParams) {

    override suspend fun doWork(): Result {
        return try {
            val coords = getCurrentLocation(applicationContext)
            if (coords != null) {
                val (lat, lon) = coords
                Log.d("TyphoonWorker", "현재 위치: $lat, $lon")
                TyphoonAlertManager.checkTyphoonAlert(applicationContext, lat, lon)
                Result.success()
            } else {
                Log.w("TyphoonWorker", "⚠️ 위치 좌표 없음 → 재시도")
                Result.retry()
            }
        } catch (e: Exception) {
            Log.e("TyphoonWorker", "워크 실행 오류", e)
            Result.retry()
        }
    }
}


