package com.edde746.plezy.shared

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Dispatch through the existing asynchronous setters, never directly into JNI. */
internal fun applyPlayerPropertyBatch(
  call: MethodCall,
  result: MethodChannel.Result,
  isCurrent: () -> Boolean,
  apply: (MethodCall, MethodChannel.Result) -> Unit
) {
  val raw = call.argument<List<*>>("properties")
  if (raw == null ||
    raw.size > 256 ||
    raw.any {
      it !is Map<*, *> || it["name"] !is String || it["value"] !is String
    }
  ) {
    result.error("INVALID_ARGS", "Invalid property batch", null)
    return
  }
  val failures = mutableListOf<Map<String, String>>()
  fun next(index: Int) {
    if (index == raw.size) {
      result.success(failures)
      return
    }
    val entry = raw[index] as Map<*, *>
    val name = entry["name"] as String
    if (!isCurrent()) {
      for (remaining in raw.drop(index)) {
        failures += mapOf("name" to ((remaining as Map<*, *>)["name"] as String), "code" to "NOT_INITIALIZED")
      }
      result.success(failures)
      return
    }
    apply(
      MethodCall("setProperty", mapOf("name" to name, "value" to entry["value"])),
      object : MethodChannel.Result {
        override fun success(value: Any?) = next(index + 1)
        override fun error(code: String, message: String?, details: Any?) {
          failures += mapOf("name" to name, "code" to code)
          next(index + 1)
        }
        override fun notImplemented() = error("NOT_IMPLEMENTED", null, null)
      }
    )
  }
  next(0)
}
