package dev.theocloud.blm

import androidx.core.content.FileProvider

/**
 * Shares the APK of an update with the package installer; a class of its own
 * so it never merges with the file provider of a plugin.
 */
class UpdateFileProvider : FileProvider()
