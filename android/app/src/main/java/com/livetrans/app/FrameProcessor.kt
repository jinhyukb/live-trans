package com.livetrans.app

import android.graphics.Bitmap
import android.graphics.Rect
import android.os.SystemClock
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import com.google.mlkit.nl.translate.Translation
import com.google.mlkit.nl.translate.Translator
import com.google.mlkit.nl.translate.TranslatorOptions
import java.util.concurrent.Executors

class FrameProcessor(private val overlay: OverlayController) {
    private val executor = Executors.newSingleThreadExecutor()
    private val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
    private val translators = mutableMapOf<String, Translator>()

    private var lastHash = -1L
    private var lastProcessedAt = 0L
    private var lastOverlayRects: List<Rect> = emptyList()

    @Volatile
    private var processing = false

    fun submit(bitmap: Bitmap) {
        val now = SystemClock.elapsedRealtime()
        if (now - lastProcessedAt < MIN_INTERVAL_MS || processing) {
            bitmap.recycle()
            return
        }
        lastProcessedAt = now
        executor.execute {
            processing = true
            try {
                process(bitmap)
            } finally {
                processing = false
            }
        }
    }

    private fun process(bitmap: Bitmap) {
        try {
            val frameHash = Fingerprinter.hash(bitmap, lastOverlayRects)
            if (frameHash == lastHash) return
            lastHash = frameHash

            val text = try {
                Tasks.await(recognizer.process(InputImage.fromBitmap(bitmap, 0)))
            } catch (e: Exception) {
                return
            }

            val blocks = text.textBlocks.mapNotNull { block ->
                val box = block.boundingBox ?: return@mapNotNull null
                val content = block.text.trim()
                if (content.length < 2 || overlapsMasked(box)) return@mapNotNull null
                Caption(box, content)
            }

            if (blocks.isEmpty()) {
                overlay.clear()
                lastOverlayRects = emptyList()
                return
            }

            val source = detectSourceLanguage(blocks)
            val translator = translatorFor(source) ?: return
            val captions = blocks.map { block ->
                Caption(block.rect, translate(translator, block.text))
            }
            overlay.show(captions)
            lastOverlayRects = captions.map { inflated(it.rect) }
        } finally {
            bitmap.recycle()
        }
    }

    private fun translatorFor(source: String): Translator? {
        translators[source]?.let { return it }
        val options = TranslatorOptions.Builder()
            .setSourceLanguage(source)
            .setTargetLanguage(TARGET_LANGUAGE)
            .build()
        val translator = Translation.getClient(options)
        return try {
            Tasks.await(translator.downloadModelIfNeeded())
            translators[source] = translator
            translator
        } catch (e: Exception) {
            translator.close()
            null
        }
    }

    private fun translate(translator: Translator, text: String): String {
        return try {
            Tasks.await(translator.translate(text)) ?: text
        } catch (e: Exception) {
            text
        }
    }

    private fun detectSourceLanguage(blocks: List<Caption>): String {
        val combined = blocks.joinToString(" ") { it.text }
        var kana = 0
        var ascii = 0
        for (character in combined) {
            val code = character.code
            when {
                code in 0x3040..0x30FF -> kana++
                code in 0x41..0x7A -> ascii++
            }
        }
        return if (kana > ascii) "ja" else "en"
    }

    private fun overlapsMasked(rect: Rect): Boolean {
        for (mask in lastOverlayRects) {
            if (Rect.intersects(mask, rect)) return true
        }
        return false
    }

    private fun inflated(rect: Rect): Rect {
        val copy = Rect(rect)
        copy.inset(-OVERLAY_PADDING, -OVERLAY_PADDING)
        return copy
    }

    private companion object {
        const val MIN_INTERVAL_MS = 700L
        const val TARGET_LANGUAGE = "ko"
        const val OVERLAY_PADDING = 20
    }
}

object Fingerprinter {
    private const val GRID = 8

    fun hash(bitmap: Bitmap, maskedRects: List<Rect>): Long {
        val scaled = Bitmap.createScaledBitmap(bitmap, GRID, GRID, false)
        val cellWidth = bitmap.width.toFloat() / GRID
        val cellHeight = bitmap.height.toFloat() / GRID
        var hash = 0L
        for (y in 0 until GRID) {
            for (x in 0 until GRID) {
                val pixel = scaled.getPixel(x, y)
                val masked = maskedRects.any { rect ->
                    rect.intersects(
                        (x * cellWidth).toInt(),
                        (y * cellHeight).toInt(),
                        ((x + 1) * cellWidth).toInt(),
                        ((y + 1) * cellHeight).toInt()
                    )
                }
                val value = if (masked) 0 else pixel and 0xFF
                hash = hash * 31 + value.toLong()
            }
        }
        scaled.recycle()
        return hash
    }
}
