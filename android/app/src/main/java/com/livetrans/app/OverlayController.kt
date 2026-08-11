package com.livetrans.app

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.Rect
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.WindowManager

data class Caption(val rect: Rect, val text: String)

class OverlayController(private val context: Context) {
    private val windowManager =
        context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val mainHandler = Handler(Looper.getMainLooper())
    private var overlayView: CaptionOverlayView? = null

    fun show(captions: List<Caption>) {
        mainHandler.post {
            val view = overlayView ?: createView().also { overlayView = it }
            view.setCaptions(captions)
        }
    }

    fun clear() {
        mainHandler.post {
            overlayView?.setCaptions(emptyList())
        }
    }

    fun teardown() {
        mainHandler.post {
            overlayView?.let { windowManager.removeView(it) }
            overlayView = null
        }
    }

    private fun createView(): CaptionOverlayView {
        val view = CaptionOverlayView(context)
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        )
        params.gravity = Gravity.TOP or Gravity.START
        windowManager.addView(view, params)
        return view
    }
}

class CaptionOverlayView(context: Context) : View(context) {
    private val backgroundPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = 0x8C000000 }
    private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        textAlign = Paint.Align.CENTER
    }
    private var captions: List<Caption> = emptyList()

    fun setCaptions(captions: List<Caption>) {
        this.captions = captions
        postInvalidate()
    }

    override fun onDraw(canvas: Canvas) {
        for (caption in captions) {
            val rect = caption.rect
            canvas.drawRect(rect, backgroundPaint)
            textPaint.textSize = (rect.height() * 0.6f).coerceIn(10f, 64f)
            val baseline = rect.centerY() - (textPaint.descent() + textPaint.ascent()) / 2f
            val clipLeft = rect.left + 8
            val clipRight = rect.right - 8
            if (clipRight > clipLeft) {
                canvas.save()
                canvas.clipRect(clipLeft, rect.top, clipRight, rect.bottom)
                canvas.drawText(caption.text, rect.centerX(), baseline, textPaint)
                canvas.restore()
            }
        }
    }
}
