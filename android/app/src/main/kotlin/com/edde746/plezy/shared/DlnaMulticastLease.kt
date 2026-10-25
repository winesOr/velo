package com.edde746.plezy.shared

import android.content.Context
import android.net.wifi.WifiManager

/** Scoped to SSDP scans, never held for playback or after the Activity exits. */
class DlnaMulticastLease {
  private var lock: WifiManager.MulticastLock? = null
  private var leases = 0

  fun acquire(context: Context) {
    val current = lock ?: (context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager)
      .createMulticastLock("velo-dlna-discovery").also {
        it.setReferenceCounted(true)
        lock = it
      }
    current.acquire()
    leases++
  }

  fun release() {
    if (leases <= 0) return
    leases--
    lock?.release()
  }

  fun dispose() {
    while (leases > 0) release()
    lock = null
  }
}
