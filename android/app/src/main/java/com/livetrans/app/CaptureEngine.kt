package com.livetrans.app

import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.Image
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.os.Handler
import android.os.HandlerThread

class CaptureEngine(
    private val projection: MediaProjection,
    private val frameSink: (Bitmap) -> Unit,
    private val width: Int,
    private val height: Int,
    private val densityDpi: Int
) {
    private val thread = HandlerThread("live-trans-capture")
    private var handler: Handler? = null
    private var imageReader: ImageReader? = null
    private var virtualDisplay: VirtualDisplay? = null

    fun start() {
        thread.start()
        val captureHandler = Handler(thread.looper)
        handler = captureHandler
        val reader = ImageReader.newInstance(width, height, PixelFormat.RGBA_8888, 2)
        imageReader = reader
        reader.setOnImageAvailableListener({ available ->
            val image = available.acquireLatestImage()
            if (image != null) {
                try {
                    frameSink(ImageUtils.toBitmap(image, width, height))
                } finally {
                    image.close()
                }
            }
        }, captureHandler)
        virtualDisplay = projection.createVirtualDisplay(
            "LiveTransCapture",
            width,
            height,
            densityDpi,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
            reader.surface,
            null,
            captureHandler
        )
    }

    fun stop() {
        virtualDisplay?.release()
        imageReader?.close()
        thread.quitSafely()
    }
}

object ImageUtils {
    fun toBitmap(image: Image, width: Int, height: Int): Bitmap {
        val plane = image.planes[0]
        val buffer = plane.buffer
        val pixelStride = plane.pixelStride
        val rowStride = plane.rowStride
        val rowPadding = rowStride - pixelStride * width
        var bitmap = Bitmap.createBitmap(
            width + rowPadding / pixelStride,
            height,
            Bitmap.Config.ARGB_8888
        )
        bitmap.copyPixelsFromBuffer(buffer)
        if (rowPadding > 0) {
            bitmap = Bitmap.createBitmap(bitmap, 0, 0, width, height)
        }
        return bitmap
    }
}
