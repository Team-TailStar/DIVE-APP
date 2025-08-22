package com.example.dive_app.worker

import android.content.Context
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.example.dive_app.manager.AccidentAlertManager

class AccidentWorker(ctx: Context, params: WorkerParameters) : CoroutineWorker(ctx, params) {
    override suspend fun doWork(): Result {
        // ⬇️ your test line goes RIGHT HERE
        Log.d("AccidentWorker", "AccidentAlertTest: worker started")

        return try {
            val payload = AccidentAlertManager.checkAndNotify(
                context = applicationContext,
                threshold = 1,        // make it easy to trigger in tests
                cooldownMinutes = 0,  // no cooldown for tests
                dryRun = true         // log only; set false to ping the watch
            )

            Log.d(
                "AccidentWorker",
                "AccidentAlertTest: result=${payload?.toString() ?: "no-alert (below threshold or no data)"}"
            )
            Result.success()
        } catch (e: Exception) {
            Log.e("AccidentWorker", "AccidentAlertTest: fail", e)
            Result.retry()
        }
    }
}
