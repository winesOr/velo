package com.edde746.plezy

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class AppUpdateValidationTest {
  @get:Rule
  val temporary = TemporaryFolder()

  @Test
  fun requiresExactSignerSetsOrForwardRotation() {
    assertTrue(AppUpdateValidation.hasCompatibleSigners(setOf("old"), setOf("old"), emptySet()))
    assertTrue(AppUpdateValidation.hasCompatibleSigners(setOf("old"), setOf("new"), setOf("old", "new")))
    assertFalse(AppUpdateValidation.hasCompatibleSigners(setOf("new"), setOf("old"), setOf("old")))
    assertFalse(AppUpdateValidation.hasCompatibleSigners(setOf("old"), setOf("unrelated"), setOf("unrelated")))
    assertFalse(AppUpdateValidation.hasCompatibleSigners(setOf("a", "b"), setOf("a"), setOf("a", "b")))
    assertTrue(AppUpdateValidation.hasCompatibleSigners(setOf("a", "b"), setOf("b", "a"), emptySet()))
    assertFalse(AppUpdateValidation.hasCompatibleSigners(emptySet(), emptySet(), emptySet()))
  }

  @Test
  fun updateCacheRejectsTraversalAndAdjacentDirectories() {
    val cache = temporary.newFolder("cache")
    val updates = File(cache, "updates").apply { mkdir() }
    val apk = File(updates, "release.apk").apply { writeText("apk") }
    val outside = File(cache, "other.apk").apply { writeText("apk") }
    val adjacent = File(cache, "updates-other").apply { mkdir() }
    val adjacentApk = File(adjacent, "release.apk").apply { writeText("apk") }

    assertTrue(AppUpdateValidation.isUpdateFile(cache, apk))
    assertFalse(AppUpdateValidation.isUpdateFile(cache, outside))
    assertFalse(AppUpdateValidation.isUpdateFile(cache, File(updates, "../other.apk")))
    assertFalse(AppUpdateValidation.isUpdateFile(cache, adjacentApk))
    assertFalse(AppUpdateValidation.isUpdateFile(cache, updates))
    assertFalse(AppUpdateValidation.isUpdateFile(cache, File(updates, "missing.apk")))
  }
}
