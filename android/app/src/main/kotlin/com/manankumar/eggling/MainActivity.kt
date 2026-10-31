package com.manankumar.eggling

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "eggling/widget")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "readActions" -> result.success(WidgetStore.actionLines(this))
                    "ackActions" -> {
                        WidgetStore.ack(this, call.arguments as? Int ?: 0)
                        result.success(null)
                    }
                    "publish" -> {
                        @Suppress("UNCHECKED_CAST")
                        val sprites = call.argument<Map<String, ByteArray>>("sprites")
                        WidgetStore.publish(this, call.argument<String>("snapshot"), sprites)
                        EgglingWidgetProvider.refreshAll(this)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
