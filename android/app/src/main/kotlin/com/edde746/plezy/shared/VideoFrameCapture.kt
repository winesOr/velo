package com.edde746.plezy.shared

import android.app.Activity
import android.content.ContentValues
import android.graphics.Bitmap
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.HandlerThread
import android.provider.MediaStore
import android.view.PixelCopy
import java.io.File
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Copies the current video plane into the gallery. Works for both cores
 * because it reads the shared [PlayerSurfaceHost] SurfaceView. Subtitles are
 * included only when the core renders them into that plane; danmaku and the
 * HUD are Flutter layers and never are. Protected (DRM) surfaces fail with a
 * copy error.
 */
internal object VideoFrameCapture {
  fun capture(activity: Activity, onResult: (Result<String>) -> Unit) {
    val surface = PlayerSurfaceHost.videoSurface
    if (surface == null || surface.width <= 0 || surface.height <= 0) {
      onResult(Result.failure(IllegalStateException("no_video_surface")))
      return
    }
    val bitmap = Bitmap.createBitmap(surface.width, surface.height, Bitmap.Config.ARGB_8888)
    val thread = HandlerThread("PlezyFrameCapture").apply { start() }
    val handler = Handler(thread.looper)
    val main = Handler(activity.mainLooper)
    PixelCopy.request(surface, bitmap, { copyResult ->
      val outcome = if (copyResult == PixelCopy.SUCCESS) {
        runCatching { save(activity, bitmap) }
      } else {
        Result.failure(IllegalStateException("pixel_copy_$copyResult"))
      }
      bitmap.recycle()
      thread.quitSafely()
      main.post { onResult(outcome) }
    }, handler)
  }

  private fun save(activity: Activity, bitmap: Bitmap): String {
    val name = "Velo_" + SimpleDateFormat("yyyyMMdd_HHmmss_SSS", Locale.US).format(Date()) + ".png"
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
      val resolver = activity.contentResolver
      val values = ContentValues().apply {
        put(MediaStore.Images.Media.DISPLAY_NAME, name)
        put(MediaStore.Images.Media.MIME_TYPE, "image/png")
        put(MediaStore.Images.Media.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/Velo")
        put(MediaStore.Images.Media.IS_PENDING, 1)
      }
      val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
        ?: throw IllegalStateException("media_store_insert")
      try {
        resolver.openOutputStream(uri)?.use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
          ?: throw IllegalStateException("media_store_open")
        values.clear()
        values.put(MediaStore.Images.Media.IS_PENDING, 0)
        resolver.update(uri, values, null, null)
      } catch (error: Throwable) {
        resolver.delete(uri, null, null)
        throw error
      }
      return uri.toString()
    }
    // Pre-Q needs storage permission for shared Pictures; the app-specific
    // directory needs none and is still reachable from a file manager.
    val dir = File(activity.getExternalFilesDir(Environment.DIRECTORY_PICTURES), "Velo").apply { mkdirs() }
    val file = File(dir, name)
    FileOutputStream(file).use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
    return file.absolutePath
  }
}
