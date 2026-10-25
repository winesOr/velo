package com.edde746.plezy.exoplayer

import android.app.Activity
import android.os.Looper
import android.widget.FrameLayout
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.exoplayer.ExoPlayer
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class AsyncSubtitleAttachmentTest {
  @Test fun cachedSidecarIsSelectableWithoutRepreparingUntilSelectedAndKeepsPauseAndPosition() {
    val activity = Robolectric.buildActivity(Activity::class.java).setup().get()
    activity.setContentView(FrameLayout(activity))
    val core = ExoPlayerCore(activity)
    try {
      assertTrue(core.initialize())
      val player = core.field("exoPlayer") as ExoPlayer
      val uri = "file:///nonexistent-startup-video.mkv"
      player.setMediaItem(MediaItem.fromUri(uri), 45_000)
      player.playWhenReady = false
      core.javaClass.getDeclaredField("currentMediaUri").apply { isAccessible = true }.set(core, uri)
      val originalItem = player.currentMediaItem

      core.addSubtitleTrack("file:///downloaded.srt", "English", "eng", "application/x-subrip", false)
      assertSame(originalItem, player.currentMediaItem)
      assertEquals(45_000L, player.currentPosition)
      assertFalse(player.playWhenReady)

      core.selectSubtitleTrack("external_pending_0")
      assertEquals(1, player.currentMediaItem!!.localConfiguration!!.subtitleConfigurations.size)
      assertEquals(45_000L, player.currentPosition)
      assertFalse(player.playWhenReady)

      core.addSubtitleTrack("file:///second.srt", "Chinese", "zho", "application/x-subrip", false)
      core.selectSubtitleTrack("external_pending_1")
      val configs = player.currentMediaItem!!.localConfiguration!!.subtitleConfigurations
      assertEquals(2, configs.size)
      assertEquals(0, configs[0].selectionFlags and C.SELECTION_FLAG_DEFAULT)
      assertEquals(C.SELECTION_FLAG_DEFAULT, configs[1].selectionFlags and C.SELECTION_FLAG_DEFAULT)
      assertEquals(45_000L, player.currentPosition)
      assertFalse(player.playWhenReady)
    } finally {
      core.dispose()
      shadowOf(Looper.getMainLooper()).idle()
    }
  }

  private fun Any.field(name: String): Any? = javaClass.getDeclaredField(name).apply { isAccessible = true }.get(this)
}
