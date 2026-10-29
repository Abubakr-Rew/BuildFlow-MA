package com.example.buildflow

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        PhotoCompressor(applicationContext).register(flutterEngine.dartExecutor.binaryMessenger)
        // Where voice notes are recorded (lib/core/audio/voice_recorder.dart).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "buildflow/paths")
            .setMethodCallHandler { call, result ->
                if (call.method == "cacheDir") result.success(cacheDir.absolutePath) else result.notImplemented()
            }
    }
}
