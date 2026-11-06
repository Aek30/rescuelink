package com.rmutt.rescuelink

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.effect.Presentation
import androidx.media3.transformer.Composition
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.VideoEncoderSettings
import io.flutter.plugin.common.MethodChannel
import java.io.File

object VideoCompressor {
    private const val TARGET_HEIGHT = 480
    private const val TARGET_BITRATE = 900_000 // ~900 kbps for fast Nearby transfer

    fun compress(
        context: Context,
        inputPath: String,
        outputPath: String,
        result: MethodChannel.Result,
    ) {
        Handler(Looper.getMainLooper()).post {
            val inputFile = File(inputPath)
            if (!inputFile.exists() || inputFile.length() <= 0L) {
                result.success(null)
                return@post
            }
            val outputFile = File(outputPath)
            outputFile.parentFile?.mkdirs()
            if (outputFile.exists()) outputFile.delete()

            try {
                val encoderFactory = DefaultEncoderFactory.Builder(context.applicationContext)
                    .setRequestedVideoEncoderSettings(
                        VideoEncoderSettings.Builder()
                            .setBitrate(TARGET_BITRATE)
                            .build()
                    )
                    .build()

                val editedMediaItem = EditedMediaItem.Builder(
                    MediaItem.fromUri(Uri.fromFile(inputFile))
                )
                    .setEffects(
                        Effects(
                            emptyList(),
                            listOf(Presentation.createForHeight(TARGET_HEIGHT))
                        )
                    )
                    .build()

                var completed = false
                val transformer = Transformer.Builder(context.applicationContext)
                    .setVideoMimeType(MimeTypes.VIDEO_H264)
                    .setAudioMimeType(MimeTypes.AUDIO_AAC)
                    .setEncoderFactory(encoderFactory)
                    .addListener(object : Transformer.Listener {
                        override fun onCompleted(
                            composition: Composition,
                            exportResult: ExportResult,
                        ) {
                            if (completed) return
                            completed = true
                            if (outputFile.exists() && outputFile.length() > 0L) {
                                result.success(outputFile.absolutePath)
                            } else {
                                outputFile.delete()
                                result.success(null)
                            }
                        }

                        override fun onError(
                            composition: Composition,
                            exportResult: ExportResult,
                            exportException: ExportException,
                        ) {
                            if (completed) return
                            completed = true
                            outputFile.delete()
                            result.success(null)
                        }
                    })
                    .build()

                transformer.start(editedMediaItem, outputFile.absolutePath)
            } catch (_: Throwable) {
                outputFile.delete()
                result.success(null)
            }
        }
    }
}

