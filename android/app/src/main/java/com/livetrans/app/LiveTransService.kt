package com.livetrans.app

import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper

class LiveTransService : Service() {
    private var capture: CaptureEngine? = null
    private var overlay: OverlayController? = null
    private var projection: MediaProjection? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val resultCode = intent?.getIntExtra(EXTRA_RESULT_CODE, Activity.RESULT_CANCELED)
            ?: Activity.RESULT_CANCELED
        @Suppress("DEPRECATION")
        val resultData = intent?.getParcelableExtra<Intent>(EXTRA_RESULT_DATA)
        if (resultCode != Activity.RESULT_OK || resultData == null) {
            stopSelf()
            return START_NOT_STICKY
        }

        ensureNotificationChannel()
        startInForeground()

        val manager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        val mediaProjection = manager.getMediaProjection(resultCode, resultData)
        val metrics = resources.displayMetrics

        val overlay = OverlayController(this)
        val processor = FrameProcessor(overlay)
        val capture = CaptureEngine(
            projection = mediaProjection,
            frameSink = processor::submit,
            width = metrics.widthPixels,
            height = metrics.heightPixels,
            densityDpi = metrics.densityDpi
        )

        this.overlay = overlay
        this.capture = capture
        this.projection = mediaProjection

        capture.start()
        mediaProjection.registerCallback(
            object : MediaProjection.Callback() {
                override fun onStop() {
                    stopEverything()
                    stopSelf()
                }
            },
            Handler(Looper.getMainLooper())
        )

        isRunning = true
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        stopEverything()
        super.onDestroy()
    }

    private fun stopEverything() {
        isRunning = false
        capture?.stop()
        projection?.stop()
        overlay?.teardown()
        capture = null
        projection = null
        overlay = null
    }

    private fun startInForeground() {
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun ensureNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "실시간 번역",
            NotificationManager.IMPORTANCE_LOW
        )
        getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            .createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification {
        val contentIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java).apply { flags = Intent.FLAG_ACTIVITY_SINGLE_TOP },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        return Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("live-trans")
            .setContentText("실시간 화면 번역이 켜져 있습니다")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentIntent(contentIntent)
            .setOngoing(true)
            .build()
    }

    companion object {
        private const val CHANNEL_ID = "live-trans-capture"
        private const val NOTIFICATION_ID = 1
        private const val EXTRA_RESULT_CODE = "resultCode"
        private const val EXTRA_RESULT_DATA = "resultData"

        @Volatile
        private var running = false

        fun start(context: Context, resultCode: Int, data: Intent) {
            val intent = Intent(context, LiveTransService::class.java).apply {
                putExtra(EXTRA_RESULT_CODE, resultCode)
                putExtra(EXTRA_RESULT_DATA, data)
            }
            context.startForegroundService(intent)
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, LiveTransService::class.java))
        }

        fun isRunning(): Boolean = running
    }
}
