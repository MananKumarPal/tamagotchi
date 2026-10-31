package com.manankumar.eggling

import android.content.Context
import org.json.JSONObject
import java.io.File
import java.util.UUID

/** The file contract with the Flutter app. See docs/widgets.md. */
object WidgetStore {
    private fun dir(context: Context) = File(context.filesDir, "widget").apply { mkdirs() }
    private fun actions(context: Context) = File(dir(context), "actions.jsonl")

    private fun writeAtomic(target: File, bytes: ByteArray) {
        val temp = File(target.parentFile, target.name + ".tmp")
        temp.writeBytes(bytes)
        temp.renameTo(target)
    }

    @Synchronized
    fun publish(context: Context, snapshot: String?, sprites: Map<String, ByteArray>?) {
        sprites?.forEach { (pose, png) -> writeAtomic(File(dir(context), "pose_$pose.png"), png) }
        if (snapshot != null) writeAtomic(File(dir(context), "snapshot.json"), snapshot.toByteArray())
    }

    @Synchronized
    fun snapshot(context: Context): JSONObject? {
        val file = File(dir(context), "snapshot.json")
        if (!file.exists()) return null
        return try {
            JSONObject(file.readText())
        } catch (_: Exception) {
            null
        }
    }

    fun sprite(context: Context, pose: String) = File(dir(context), "pose_$pose.png")

    @Synchronized
    fun actionLines(context: Context): List<String> {
        val file = actions(context)
        return if (file.exists()) file.readLines().filter { it.isNotBlank() } else emptyList()
    }

    /** Returns only after the action is on disk. */
    @Synchronized
    fun append(context: Context, type: String) {
        val line = JSONObject()
            .put("id", UUID.randomUUID().toString())
            .put("type", type)
            .put("at", System.currentTimeMillis())
        val existing = actionLines(context)
        writeAtomic(actions(context), (existing + line.toString()).joinToString("\n", postfix = "\n").toByteArray())
    }

    @Synchronized
    fun ack(context: Context, count: Int) {
        val rest = actionLines(context).drop(count)
        writeAtomic(actions(context), rest.joinToString("") { it + "\n" }.toByteArray())
    }
}
