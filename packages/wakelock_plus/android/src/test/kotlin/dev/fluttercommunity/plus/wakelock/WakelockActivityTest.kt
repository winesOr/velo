package dev.fluttercommunity.plus.wakelock

import ToggleMessage
import android.app.Activity
import android.view.WindowManager
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class WakelockActivityTest {
  @Test
  fun enabledRequestIsReplayedOnTheReplacementWindow() {
    val first = Robolectric.buildActivity(Activity::class.java).setup()
    val replacement = Robolectric.buildActivity(Activity::class.java).setup()
    val wakelock = Wakelock()
    try {
      wakelock.activity = first.get()
      wakelock.toggle(ToggleMessage(enable = true))
      assertTrue(keepsScreenOn(first.get()))
      wakelock.activity = null
      wakelock.activity = replacement.get()
      assertTrue(keepsScreenOn(replacement.get()))
    } finally {
      first.pause().stop().destroy()
      replacement.pause().stop().destroy()
    }
  }

  @Test
  fun detachedReleaseSupersedesThePreviousEnable() {
    val activity = Robolectric.buildActivity(Activity::class.java).setup()
    val wakelock = Wakelock()
    try {
      wakelock.activity = activity.get()
      wakelock.toggle(ToggleMessage(enable = true))
      wakelock.activity = null
      assertThrows(NoActivityException::class.java) { wakelock.toggle(ToggleMessage(enable = false)) }
      wakelock.activity = activity.get()
      assertFalse(keepsScreenOn(activity.get()))
    } finally {
      activity.pause().stop().destroy()
    }
  }

  @Test
  fun anEnableReceivedWhileDetachedIsAppliedOnAttach() {
    val activity = Robolectric.buildActivity(Activity::class.java).setup()
    val wakelock = Wakelock()
    try {
      assertThrows(NoActivityException::class.java) { wakelock.toggle(ToggleMessage(enable = true)) }
      wakelock.activity = activity.get()
      assertTrue(keepsScreenOn(activity.get()))
      wakelock.toggle(ToggleMessage(enable = false))
      assertFalse(keepsScreenOn(activity.get()))
    } finally {
      activity.pause().stop().destroy()
    }
  }

  @Test
  fun repeatingRequestsPreservesUnrelatedWindowFlags() {
    val activity = Robolectric.buildActivity(Activity::class.java).setup()
    val wakelock = Wakelock()
    try {
      activity.get().window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
      wakelock.activity = activity.get()
      repeat(2) { wakelock.toggle(ToggleMessage(enable = true)) }
      repeat(2) { wakelock.toggle(ToggleMessage(enable = false)) }
      assertFalse(keepsScreenOn(activity.get()))
      assertTrue(activity.get().window.attributes.flags and WindowManager.LayoutParams.FLAG_SECURE != 0)
    } finally {
      activity.pause().stop().destroy()
    }
  }

  private fun keepsScreenOn(activity: Activity): Boolean = activity.window.attributes.flags and WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON != 0
}
