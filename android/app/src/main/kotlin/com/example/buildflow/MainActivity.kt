package com.example.buildflow

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        PhotoCompressor(applicationContext).register(flutterEngine.dartExecutor.binaryMessenger)
    }
}
