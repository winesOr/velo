package com.edde746.plezy.shared

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.junit.Assert.*
import org.junit.Test

class PlayerPropertyBatchTest {
  private class Reply : MethodChannel.Result {
    var completions = 0
    var value: Any? = null
    var code: String? = null
    override fun success(result: Any?) {
      completions++
      value = result
    }
    override fun error(errorCode: String, message: String?, details: Any?) {
      completions++
      code = errorCode
    }
    override fun notImplemented() {
      completions++
    }
  }

  private fun batch() = MethodCall(
    "setProperties",
    mapOf(
      "properties" to listOf(
        mapOf("name" to "first", "value" to "1"),
        mapOf("name" to "second", "value" to "2")
      )
    )
  )

  @Test fun waitsForEveryCallbackAndKeepsOrder() {
    val reply = Reply()
    val names = mutableListOf<String>()
    var pending: MethodChannel.Result? = null
    applyPlayerPropertyBatch(batch(), reply, { true }) { call, result ->
      names += call.argument<String>("name")!!
      pending = result
    }
    assertEquals(listOf("first"), names)
    assertEquals(0, reply.completions)
    pending!!.success(null)
    assertEquals(listOf("first", "second"), names)
    assertEquals(0, reply.completions)
    pending!!.success(null)
    assertEquals(1, reply.completions)
    assertEquals(emptyList<Any>(), reply.value)
  }

  @Test fun failureDoesNotSkipLaterPreferencesOrExposeValues() {
    val reply = Reply()
    val names = mutableListOf<String>()
    applyPlayerPropertyBatch(batch(), reply, { true }) { call, result ->
      val name = call.argument<String>("name")!!
      names += name
      if (name == "first") {
        result.error("SET_PROPERTY_FAILED", "private value", "private details")
      } else {
        result.success(null)
      }
    }
    assertEquals(listOf("first", "second"), names)
    assertEquals(listOf(mapOf("name" to "first", "code" to "SET_PROPERTY_FAILED")), reply.value)
  }

  @Test fun replacementCannotReceiveRemainingWrites() {
    val reply = Reply()
    var current = true
    val names = mutableListOf<String>()
    applyPlayerPropertyBatch(batch(), reply, { current }) { call, result ->
      names += call.argument<String>("name")!!
      current = false
      result.success(null)
    }
    assertEquals(listOf("first"), names)
    assertEquals(listOf(mapOf("name" to "second", "code" to "NOT_INITIALIZED")), reply.value)
  }

  @Test fun validatesWholeBatchBeforeWriting() {
    val reply = Reply()
    applyPlayerPropertyBatch(
      MethodCall(
        "setProperties",
        mapOf(
          "properties" to listOf(
            mapOf("name" to "first", "value" to "1"),
            mapOf("name" to "bad", "value" to 5)
          )
        )
      ),
      reply,
      { true }
    ) { _, _ -> fail("Invalid batch must not write") }
    assertEquals("INVALID_ARGS", reply.code)
    assertEquals(1, reply.completions)
  }
}
