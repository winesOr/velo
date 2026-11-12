package com.edde746.plezy.exoplayer

import android.app.Activity
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.analytics.AnalyticsListener
import androidx.media3.exoplayer.source.SinglePeriodTimeline
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class ExoPlayerPlaybackActivityTest {
  @Test
  fun snapshotsSeparateBufferingIntentFromLegacyPlayingProperties() {
    val core = ExoPlayerCore(Robolectric.buildActivity(Activity::class.java).setup().get())
    val delegate = RecordingDelegate()
    core.delegate = delegate
    setField(core, "currentMediaGeneration", 7)
    try {
      for ((state, phase) in listOf(
        Player.STATE_IDLE to "idle",
        Player.STATE_BUFFERING to "buffering",
        Player.STATE_READY to "ready",
        Player.STATE_ENDED to "ended"
      )) {
        for (requested in listOf(false, true)) {
          emitActivity(core, state, requested, 7)
          assertEquals(
            mapOf("sourceId" to 7L, "phase" to phase, "playWhenReady" to requested),
            delegate.events.last().second
          )
        }
      }
      assertEquals(8, delegate.events.size)
      assertTrue(delegate.events.all { it.first == "playback-activity" })
      assertTrue(delegate.properties.isEmpty())
      emitActivity(core, Player.STATE_READY, true, 6)
      emitActivity(core, -1, true, 7)
      assertEquals(8, delegate.events.size)
    } finally {
      core.dispose()
    }
  }

  @Test
  fun nativePlayIntentChangesPublishEvenWhenIsPlayingDidNotChange() {
    val activity = Robolectric.buildActivity(Activity::class.java).setup().get()
    val core = ExoPlayerCore(activity)
    val delegate = RecordingDelegate()
    core.delegate = delegate
    setField(core, "currentMediaGeneration", 9)
    setField(core, "exoPlayer", ExoPlayer.Builder(activity).build())
    val analytics = getField(core, "decoderHangListener") as AnalyticsListener
    try {
      analytics.onPlayWhenReadyChanged(eventTime(9), true, Player.PLAY_WHEN_READY_CHANGE_REASON_USER_REQUEST)
      analytics.onPlayWhenReadyChanged(eventTime(9), false, Player.PLAY_WHEN_READY_CHANGE_REASON_USER_REQUEST)
      analytics.onPlayWhenReadyChanged(eventTime(8), true, Player.PLAY_WHEN_READY_CHANGE_REASON_USER_REQUEST)
      assertEquals(listOf(true, false), delegate.events.map { it.second?.get("playWhenReady") })
      assertTrue(delegate.events.all { it.second?.get("sourceId") == 9L })
      assertTrue(delegate.properties.isEmpty())
    } finally {
      core.dispose()
    }
  }

  private fun emitActivity(core: ExoPlayerCore, state: Int, requested: Boolean, generation: Int) {
    val method = ExoPlayerCore::class.java.getDeclaredMethod(
      "emitPlaybackActivity",
      Int::class.javaPrimitiveType,
      Boolean::class.javaPrimitiveType,
      Int::class.javaPrimitiveType
    )
    method.isAccessible = true
    method.invoke(core, state, requested, generation)
  }

  private fun eventTime(generation: Int): AnalyticsListener.EventTime {
    val media = MediaItem.Builder().setMediaId(generation.toString()).setUri("https://example.invalid/video").build()
    val timeline = SinglePeriodTimeline(1_000_000L, true, false, false, null, media)
    return AnalyticsListener.EventTime(0L, timeline, 0, null, 0L, timeline, 0, null, 0L, 0L)
  }

  private fun setField(core: ExoPlayerCore, name: String, value: Any?) {
    ExoPlayerCore::class.java.getDeclaredField(name).apply { isAccessible = true }.set(core, value)
  }

  private fun getField(core: ExoPlayerCore, name: String): Any? = ExoPlayerCore::class.java.getDeclaredField(name).apply { isAccessible = true }.get(core)

  private class RecordingDelegate : ExoPlayerDelegate {
    val properties = mutableListOf<Pair<String, Any?>>()
    val events = mutableListOf<Pair<String, Map<String, Any>?>>()

    override fun onPropertyChange(name: String, value: Any?) {
      properties += name to value
    }

    override fun onEvent(name: String, data: Map<String, Any>?) {
      events += name to data
    }
  }
}
