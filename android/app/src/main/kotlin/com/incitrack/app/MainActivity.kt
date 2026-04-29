package com.incitrack.app

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.incitrack.app/downloads",
        ).setMethodCallHandler { call, result ->
            if (call.method != "saveCsvToDownloads") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val fileName = call.argument<String>("fileName")
            val content = call.argument<String>("content")

            if (fileName.isNullOrBlank() || content == null) {
                result.error("INVALID_ARGS", "fileName and content are required.", null)
                return@setMethodCallHandler
            }

            try {
                val savedPath = saveCsvToDownloads(fileName, content)
                result.success(savedPath)
            } catch (exception: Exception) {
                result.error("SAVE_FAILED", exception.message, null)
            }
        }
    }

    private fun saveCsvToDownloads(fileName: String, content: String): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = applicationContext.contentResolver
            val values =
                ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                    put(MediaStore.MediaColumns.MIME_TYPE, "text/csv")
                    put(
                        MediaStore.MediaColumns.RELATIVE_PATH,
                        Environment.DIRECTORY_DOWNLOADS,
                    )
                    put(MediaStore.MediaColumns.IS_PENDING, 1)
                }

            val collection =
                MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            val uri =
                resolver.insert(collection, values)
                    ?: throw IOException("Could not create the download entry.")

            resolver.openOutputStream(uri)?.use { outputStream ->
                outputStream.write(content.toByteArray(Charsets.UTF_8))
                outputStream.flush()
            } ?: throw IOException("Could not open the download output stream.")

            values.clear()
            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
            resolver.update(uri, values, null, null)

            return "Downloads/$fileName"
        }

        val downloadsDirectory =
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        if (!downloadsDirectory.exists() && !downloadsDirectory.mkdirs()) {
            throw IOException("Could not access the Downloads folder.")
        }

        val outputFile = File(downloadsDirectory, fileName)
        outputFile.writeText(content)
        return outputFile.absolutePath
    }
}
