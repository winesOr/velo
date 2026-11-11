package com.edde746.plezy

import android.app.Activity
import android.app.KeyguardManager
import android.os.PowerManager
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class AppUpdateForegroundTest {
  @Test
  fun blocksInstallerWhenActivityPausesLosesFocusOrPhoneLocks() {
    val controller = Robolectric.buildActivity(UpdateActivity::class.java).setup().visible()
    val activity = controller.get()
    val power = shadowOf(activity.getSystemService(PowerManager::class.java))
    val keyguard = shadowOf(activity.getSystemService(KeyguardManager::class.java))
    activity.registry.currentState = Lifecycle.State.RESUMED
    controller.windowFocusChanged(true)
    power.setIsInteractive(true)
    keyguard.setKeyguardLocked(false)
    assertTrue(AppUpdateChannel.canLaunchUpdateUi(activity))

    activity.registry.currentState = Lifecycle.State.STARTED
    assertFalse(AppUpdateChannel.canLaunchUpdateUi(activity))
    activity.registry.currentState = Lifecycle.State.RESUMED
    controller.windowFocusChanged(false)
    assertFalse(AppUpdateChannel.canLaunchUpdateUi(activity))
    controller.windowFocusChanged(true)
    keyguard.setKeyguardLocked(true)
    assertFalse(AppUpdateChannel.canLaunchUpdateUi(activity))
    keyguard.setKeyguardLocked(false)
    power.setIsInteractive(false)
    assertFalse(AppUpdateChannel.canLaunchUpdateUi(activity))
    controller.pause().stop().destroy()
  }

  class UpdateActivity :
    Activity(),
    LifecycleOwner {
    val registry = LifecycleRegistry(this)
    override val lifecycle: Lifecycle
      get() = registry
  }
}
