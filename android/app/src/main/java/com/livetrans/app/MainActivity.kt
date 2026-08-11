package com.livetrans.app

import android.app.Activity
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import android.widget.Button
import android.widget.TextView

class MainActivity : Activity() {
    private val overlayRequestCode = 1001
    private val projectionRequestCode = 1002

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        findViewById<Button>(R.id.toggleButton).setOnClickListener { onToggle() }
    }

    private fun onToggle() {
        if (LiveTransService.isRunning()) {
            LiveTransService.stop(this)
            updateUi()
            return
        }
        if (!Settings.canDrawOverlays(this)) {
            startActivityForResult(
                Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:$packageName")
                ),
                overlayRequestCode
            )
            return
        }
        requestProjection()
    }

    private fun requestProjection() {
        val manager = getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        startActivityForResult(manager.createScreenCaptureIntent(), projectionRequestCode)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        when (requestCode) {
            overlayRequestCode -> updateUi()
            projectionRequestCode -> {
                if (resultCode == Activity.RESULT_OK && data != null) {
                    LiveTransService.start(this, resultCode, data)
                }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        updateUi()
    }

    private fun updateUi() {
        val running = LiveTransService.isRunning()
        findViewById<Button>(R.id.toggleButton).setText(if (running) "번역 중지" else "번역 시작")
        findViewById<TextView>(R.id.statusText).text = if (running)
            "켜져 있어요 — 지금 화면이 실시간 번역되고 있습니다"
        else
            "꺼져 있어요"
    }
}
