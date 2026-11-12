package dev.fluttercommunity.plus.wakelock

import IsEnabledMessage
import ToggleMessage
import android.app.Activity
import android.view.WindowManager

internal class Wakelock {
  private var requestedEnabled = false

  var activity: Activity? = null
    set(value) {
      field = value
      if (value != null) applyRequestedState()
    }

  private val enabled
    get() = activity!!.window.attributes.flags and
      WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON != 0

  fun toggle(message: ToggleMessage) {
    // Keep the latest Dart owner request even while the Activity is detached.
    // In particular, a release must supersede an earlier enable before reattach.
    requestedEnabled = message.enable!!
    applyRequestedState()
  }

  private fun applyRequestedState() {
    if (activity == null) {
      throw NoActivityException()
    }

    val activity = this.activity!!
    val enabled = this.enabled

    if (requestedEnabled) {
      if (!enabled) activity.window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    } else if (enabled) {
      activity.window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }
  }

  fun isEnabled(): IsEnabledMessage {
    if (activity == null) {
      throw NoActivityException()
    }

    return IsEnabledMessage(enabled = enabled)
  }
}

class NoActivityException : Exception("wakelock requires a foreground activity")
