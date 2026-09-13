package com.practicerecorder.practice_recorder

import android.content.ContentUris
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.practicerecorder/gallery"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "deleteVideosByNames" -> {
                        val names = call.argument<List<String>>("names").orEmpty()
                        try {
                            result.success(deleteVideosByDisplayNames(names))
                        } catch (e: Exception) {
                            result.error("DELETE_FAILED", e.message, null)
                        }
                    }
                    "setKeepScreenOn" -> {
                        val on = call.argument<Boolean>("on") ?: false
                        runOnUiThread {
                            if (on) {
                                window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                            } else {
                                window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                            }
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun deleteVideosByDisplayNames(names: List<String>): Int {
        if (names.isEmpty()) return 0
        var deleted = 0
        val resolver = contentResolver
        val collection: Uri =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
            } else {
                MediaStore.Video.Media.EXTERNAL_CONTENT_URI
            }

        for (name in names) {
            val selection = "${MediaStore.Video.Media.DISPLAY_NAME}=?"
            resolver.query(
                collection,
                arrayOf(MediaStore.Video.Media._ID),
                selection,
                arrayOf(name),
                null,
            )?.use { cursor ->
                val idIndex = cursor.getColumnIndexOrThrow(MediaStore.Video.Media._ID)
                while (cursor.moveToNext()) {
                    val id = cursor.getLong(idIndex)
                    val uri = ContentUris.withAppendedId(collection, id)
                    val rows = try {
                        resolver.delete(uri, null, null)
                    } catch (_: SecurityException) {
                        0
                    }
                    if (rows > 0) deleted += rows
                }
            }
        }
        return deleted
    }
}
